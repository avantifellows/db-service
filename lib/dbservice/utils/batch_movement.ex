# dbservice/lib/utils

defmodule Dbservice.DataImport.BatchMovement do
  @moduledoc """
  This module handles batch movement processing for importing student batch changes.
  It processes batch movement records by:
  1. Finding the student by student_id
  2. Finding the new batch by batch_id
  3. Updating group_user records to reflect the new batch
  4. Creating new enrollment records for the new batch (isCurrent=true)
  5. Updating old batch enrollment records (isCurrent=false)
  6. Handling grade movement if grade is provided
  """

  alias Dbservice.Users
  alias Dbservice.GroupUsers
  alias Dbservice.Services.BatchEnrollmentService

  def process_batch_movement(record) do
    with {:ok, student} <- get_student(record["student_id"]),
         {batch_group_id, batch_id, batch_group_type} <- BatchEnrollmentService.get_batch_info(record["batch_id"]),
         {:ok, _} <- handle_batch_movement(student, {batch_group_id, batch_id, batch_group_type}, record) do
      {:ok, "Batch movement processed successfully"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_student(student_id) do
    case Users.get_student_by_student_id(student_id) do
      nil -> {:error, "Student not found with ID: #{student_id}"}
      student -> {:ok, student}
    end
  end

  defp handle_batch_movement(student, {batch_group_id, batch_id, batch_group_type}, record) do
    user_id = student.user_id
    start_date = record["start_date"]
    academic_year = record["academic_year"]

    # Get group users for the student
    group_users = GroupUsers.get_group_user_by_user_id(user_id)

    {status_id, status_group_type} = BatchEnrollmentService.get_enrolled_status_info()

    # Check if the student is already enrolled in the specified batch
    unless BatchEnrollmentService.existing_batch_enrollment?(user_id, batch_id) do
      # Handle the batch enrollment process
      BatchEnrollmentService.handle_batch_enrollment(
        user_id,
        batch_id,
        batch_group_type,
        academic_year,
        start_date
      )

      BatchEnrollmentService.handle_status_enrollment(
        user_id,
        status_id,
        status_group_type,
        academic_year,
        start_date
      )

    end

    # Handle grade movement if grade is provided
    if Map.has_key?(record, "grade") && record["grade"] != "" do
      case BatchEnrollmentService.get_grade_info(record["grade"]) do
        {grade_group_id, grade_id, grade_group_type} ->
          # Check if grade has changed
          if BatchEnrollmentService.grade_changed?(user_id, grade_id) do
            # Handle grade enrollment
            BatchEnrollmentService.handle_grade_enrollment(
              user_id,
              grade_id,
              grade_group_type,
              academic_year,
              start_date
            )

            # Update grade in group_user
            BatchEnrollmentService.update_grade_user(user_id, grade_group_id, group_users)

            # Update grade in student table
            BatchEnrollmentService.update_student_grade(student, grade_id)
          end

        nil ->
          # Grade not found, but continue with batch movement
          :ok
      end
    end

    # Always update the batch group user
    BatchEnrollmentService.update_batch_user(user_id, batch_group_id, group_users)

    {:ok, "Batch movement completed"}
  end
end
