defmodule Dbservice.DataImport.TeacherBatchAssignment do
  @moduledoc """
  This module handles teacher batch assignment processing for importing teacher batch assignments.
  It processes teacher batch assignment records by:
  1. Finding the teacher by teacher_id
  2. Finding the batch by batch_id
  3. Updating group_user records to reflect the new batch assignment
  4. Creating new enrollment records for the new batch (isCurrent=true)
  5. Updating old batch enrollment records (isCurrent=false)
  """

  alias Dbservice.Users
  alias Dbservice.GroupUsers
  alias Dbservice.Services.BatchEnrollmentService

  def process_teacher_batch_assignment(record) do
    case Users.get_teacher_by_teacher_id(record["teacher_id"]) do
      nil ->
        {:error, "Teacher not found with ID: #{record["teacher_id"]}"}

      teacher ->
        case BatchEnrollmentService.get_batch_info(record["batch_id"]) do
          nil ->
            {:error, "Batch not found with ID: #{record["batch_id"]}"}

          {batch_group_id, batch_id, batch_group_type} ->
            case handle_teacher_batch_assignment(
                   teacher,
                   {batch_group_id, batch_id, batch_group_type},
                   record
                 ) do
              {:ok, _} -> {:ok, "Teacher batch assignment processed successfully"}
              {:error, reason} -> {:error, reason}
            end
        end
    end
  end

  defp handle_teacher_batch_assignment(
         teacher,
         {batch_group_id, batch_id, batch_group_type},
         record
       ) do
    user_id = teacher.user_id
    start_date = record["start_date"]
    academic_year = record["academic_year"]

    # Get group users for the teacher
    group_users = GroupUsers.get_group_user_by_user_id(user_id)

    # Handle batch enrollment (no status for teachers)
    handle_batch_enrollment(
      user_id,
      batch_id,
      batch_group_type,
      academic_year,
      start_date
    )

    # Always update the batch group user
    BatchEnrollmentService.update_batch_user(user_id, batch_group_id, group_users)

    {:ok, "Teacher batch assignment completed"}
  end

  defp handle_batch_enrollment(user_id, batch_id, batch_group_type, academic_year, start_date) do
    is_already_assigned =
      BatchEnrollmentService.existing_batch_enrollment?(user_id, batch_id)

    if is_already_assigned do
      :already_assigned
    else
      # Handle the batch enrollment process using existing service
      BatchEnrollmentService.handle_batch_enrollment(
        user_id,
        batch_id,
        batch_group_type,
        academic_year,
        start_date
      )
    end
  end
end
