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
  """

  alias Dbservice.Users
  alias Dbservice.GroupUsers
  alias Dbservice.Services.BatchEnrollmentService

  def process_batch_movement(record) do
    with {:ok, student} <- get_student(record["student_id"]),
         {:ok, batch_info} <- BatchEnrollmentService.get_batch_info(record["batch_id"]),
         {:ok, _} <- handle_batch_movement(student, batch_info, record) do
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
    end

    # Always update the batch group user
    BatchEnrollmentService.update_batch_user(user_id, batch_group_id, group_users)

    {:ok, "Batch movement completed"}
  end
end
