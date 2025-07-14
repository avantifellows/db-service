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
    with {:ok, student} <- Users.get_student_by_student_id_with_error(record["student_id"]),
         {batch_group_id, batch_id, batch_group_type} <-
           BatchEnrollmentService.get_batch_info(record["batch_id"]),
         {:ok, _} <-
           handle_batch_movement(student, {batch_group_id, batch_id, batch_group_type}, record) do
      {:ok, "Batch movement processed successfully"}
    else
      {:error, :student_not_found} ->
        {:error, "Student not found with ID: #{record["student_id"]}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_batch_movement(student, {batch_group_id, batch_id, batch_group_type}, record) do
    user_id = student.user_id
    start_date = record["start_date"]
    academic_year = record["academic_year"]

    # Get group users for the student
    group_users = GroupUsers.get_group_user_by_user_id(user_id)

    # Handle batch and status enrollment
    handle_batch_and_status_enrollment(
      user_id,
      batch_id,
      batch_group_type,
      academic_year,
      start_date
    )

    # Handle grade movement if provided
    handle_grade_movement(student, record, user_id, academic_year, start_date, group_users)

    # Always update the batch group user
    BatchEnrollmentService.update_batch_user(user_id, batch_group_id, group_users)

    {:ok, "Batch movement completed"}
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
      :already_enrolled
    else
      # Handle the batch enrollment process
      BatchEnrollmentService.handle_batch_enrollment(
        user_id,
        batch_id,
        batch_group_type,
        academic_year,
        start_date
      )

      # Handle the status enrollment process
      {status_id, status_group_type} = BatchEnrollmentService.get_enrolled_status_info()

      BatchEnrollmentService.handle_status_enrollment(
        user_id,
        status_id,
        status_group_type,
        academic_year,
        start_date
      )
    end
  end

  defp handle_grade_movement(student, record, user_id, academic_year, start_date, group_users) do
    has_grade = Map.has_key?(record, "grade") && record["grade"] != ""

    if has_grade do
      process_grade_change(
        student,
        record["grade"],
        user_id,
        academic_year,
        start_date,
        group_users
      )
    else
      :no_grade_change
    end
  end

  defp process_grade_change(student, grade, user_id, academic_year, start_date, group_users) do
    case BatchEnrollmentService.get_grade_info(grade) do
      {grade_group_id, grade_id, grade_group_type} ->
        handle_grade_enrollment_if_changed(
          student,
          user_id,
          grade_id,
          grade_group_id,
          grade_group_type,
          academic_year,
          start_date,
          group_users
        )

      nil ->
        :grade_not_found
    end
  end

  defp handle_grade_enrollment_if_changed(
         student,
         user_id,
         grade_id,
         grade_group_id,
         grade_group_type,
         academic_year,
         start_date,
         group_users
       ) do
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
    else
      :grade_unchanged
    end
  end
end
