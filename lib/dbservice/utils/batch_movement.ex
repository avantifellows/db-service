# dbservice/lib/utils

defmodule Dbservice.DataImport.BatchMovement do
  @moduledoc """
  This module handles batch movement processing for importing student batch changes.
  It processes batch movement records by:
  1. Finding the student by student_id or apaar_id
  2. Finding the new batch by batch_id
  3. Updating group_user records to reflect the new batch
  4. Creating new enrollment records for the new batch (isCurrent=true)
  5. Updating old batch enrollment records (isCurrent=false)
  6. Handling grade movement if grade is provided

  Step 5 ends *every* other current batch the student holds, including batches
  belonging to other programs — see `release_previous_batches/3`.
  """

  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Services.BatchEnrollmentService
  alias Dbservice.Utils.ChangesetFormatter

  def process_batch_movement(record) do
    case Users.get_student_by_id_or_apaar_id(record) do
      {:error, {:ambiguous_student, _, _} = reason} ->
        {:error, Users.ambiguous_student_message(reason)}

      nil ->
        {:error,
         "Student not found. student_id: #{record["student_id"]}, apaar_id: #{record["apaar_id"]}"}

      student ->
        process_student_with_batch(student, record)
    end
  end

  defp process_student_with_batch(student, record) do
    if student.status == "dropout" do
      student_identifier = student.student_id || student.apaar_id

      {:error,
       "Cannot process batch movement for student id: #{student_identifier} because status is dropout"}
    else
      process_with_batch_info(student, record)
    end
  end

  defp process_with_batch_info(student, record) do
    case BatchEnrollmentService.get_batch_info(record["batch_id"]) do
      nil ->
        {:error, "Batch not found with ID: #{record["batch_id"]}"}

      {batch_group_id, batch_id, batch_group_type} ->
        case handle_batch_movement(
               student,
               {batch_group_id, batch_id, batch_group_type},
               record
             ) do
          {:ok, _} -> {:ok, "Batch movement processed successfully"}
          {:error, reason} -> {:error, describe(reason)}
        end
    end
  end

  # The batches being left are closed *before* the new enrollment is created, so a
  # failed create would otherwise leave the student with no current batch at all -
  # and because each step's result was discarded, the import still reported
  # "processed successfully". Running the movement in one transaction means a row
  # that cannot complete changes nothing and is reported as failed.
  defp handle_batch_movement(student, {batch_group_id, batch_id, batch_group_type}, record) do
    user_id = student.user_id
    start_date = record["start_date"]
    academic_year = record["academic_year"]

    Repo.transaction(fn ->
      # update_all over the batches being left; nothing here can fail softly.
      release_previous_batches(user_id, batch_id, start_date)

      with :ok <-
             handle_batch_and_status_enrollment(
               user_id,
               batch_id,
               batch_group_type,
               academic_year,
               start_date
             ),
           :ok <- handle_grade_movement(student, record, user_id, academic_year, start_date),
           # Always update the batch group user. Runs after the release so the
           # target program's memberships get the final say.
           :ok <- step(BatchEnrollmentService.update_batch_user(user_id, batch_group_id)) do
        "Batch movement completed"
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # The enrollment/membership helpers return {:ok, record} | {:error, changeset};
  # a movement only cares whether the step went through.
  defp step({:ok, _}), do: :ok
  defp step({:error, reason}), do: {:error, reason}

  defp describe(%Ecto.Changeset{} = changeset),
    do: "Batch movement failed: #{ChangesetFormatter.format_errors(changeset)}"

  defp describe(reason) when is_binary(reason), do: reason
  defp describe(reason), do: "Batch movement failed: #{inspect(reason)}"

  # A batch movement is a move, so every batch the student currently holds is
  # left behind, whatever program it belongs to.
  #
  # `handle_batch_enrollment/5` only ends current batch ERs in the *target*
  # batch's program, which is right for the enrollment API — a student can be
  # added to a second program's batch without leaving the first. But a move
  # across programs then reads as a second enrollment and the old batch stays
  # current (Punjab `..._common_A001` -> `..._engg_N001`), which is what breaks
  # Gurukul. This import knows better, so it closes the rest itself.
  defp release_previous_batches(user_id, target_batch_id, start_date) do
    BatchEnrollmentService.release_other_batch_enrollments(
      user_id,
      target_batch_id,
      start_date
    )
  end

  defp handle_batch_and_status_enrollment(
         user_id,
         batch_id,
         batch_group_type,
         academic_year,
         start_date
       ) do
    is_already_enrolled =
      BatchEnrollmentService.existing_batch_enrollment?(user_id, batch_id)

    if is_already_enrolled do
      :ok
    else
      # Handle the batch enrollment process
      with :ok <-
             step(
               BatchEnrollmentService.handle_batch_enrollment(
                 user_id,
                 batch_id,
                 batch_group_type,
                 academic_year,
                 start_date
               )
             ) do
        # Handle the status enrollment process
        {status_id, status_group_type} = BatchEnrollmentService.get_enrolled_status_info()

        step(
          BatchEnrollmentService.handle_status_enrollment(
            user_id,
            status_id,
            status_group_type,
            academic_year,
            start_date
          )
        )
      end
    end
  end

  defp handle_grade_movement(student, record, user_id, academic_year, start_date) do
    has_grade = Map.has_key?(record, "grade") && record["grade"] != nil && record["grade"] != ""

    if has_grade do
      process_grade_change(
        student,
        record["grade"],
        user_id,
        academic_year,
        start_date
      )
    else
      :ok
    end
  end

  defp process_grade_change(student, grade, user_id, academic_year, start_date) do
    case BatchEnrollmentService.get_grade_info(grade) do
      # Unchanged behaviour: an unknown grade is skipped rather than failing the
      # row, so this is not an error the transaction rolls back on.
      nil ->
        :ok

      {grade_group_id, grade_id, grade_group_type} ->
        handle_grade_enrollment_if_changed(
          student,
          user_id,
          grade_id,
          grade_group_id,
          grade_group_type,
          academic_year,
          start_date
        )
    end
  end

  defp handle_grade_enrollment_if_changed(
         student,
         user_id,
         grade_id,
         grade_group_id,
         grade_group_type,
         academic_year,
         start_date
       ) do
    if BatchEnrollmentService.grade_changed?(user_id, grade_id) do
      # Handle grade enrollment
      with :ok <-
             step(
               BatchEnrollmentService.handle_grade_enrollment(
                 user_id,
                 grade_id,
                 grade_group_type,
                 academic_year,
                 start_date
               )
             ),
           # Update grade in group_user
           :ok <- step(BatchEnrollmentService.update_grade_user(user_id, grade_group_id)) do
        # Update grade in student table
        step(BatchEnrollmentService.update_student_grade(student, grade_id))
      end
    else
      :ok
    end
  end
end
