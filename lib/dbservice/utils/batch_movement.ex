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

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Batches
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  def process_batch_movement(record) do
    with {:ok, student} <- get_student(record["student_id"]),
         {:ok, batch} <- get_batch(record["batch_id"]),
         {:ok, batch_group} <- get_batch_group(batch.id),
         {:ok, _} <- update_batch_enrollment(student.user_id, batch_group.id, batch.id, record) do
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

  defp get_batch(batch_id) do
    case Batches.get_batch_by_batch_id(batch_id) do
      nil -> {:error, "Batch not found with ID: #{batch_id}"}
      batch -> {:ok, batch}
    end
  end

  defp get_batch_group(batch_id) do
    case Groups.get_group_by_child_id_and_type(batch_id, "batch") do
      nil -> {:error, "Batch group not found for batch ID: #{batch_id}"}
      group -> {:ok, group}
    end
  end

  defp update_batch_enrollment(user_id, new_batch_group_id, new_batch_id, record) do
    Repo.transaction(fn ->
      with {:ok, _} <- update_existing_batch_enrollments(user_id, record["start_date"]),
           {:ok, _} <- create_new_batch_enrollment(user_id, new_batch_id, record),
           {:ok, _} <- update_group_user_batch(user_id, new_batch_group_id) do
        {:ok, "Batch movement completed"}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp update_existing_batch_enrollments(user_id, start_date) do
    # Mark all current batch enrollments as not current and set end_date
    {updated_count, _} =
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true,
        update: [set: [is_current: false, end_date: ^start_date]]
      )
      |> Repo.update_all([])

    {:ok, updated_count}
  end

  defp create_new_batch_enrollment(user_id, batch_id, record) do
    enrollment_attrs = %{
      user_id: user_id,
      group_id: batch_id,
      group_type: "batch",
      academic_year: record["academic_year"],
      start_date: record["start_date"],
      is_current: true
    }

    case EnrollmentRecords.create_enrollment_record(enrollment_attrs) do
      {:ok, enrollment} -> {:ok, enrollment}
      {:error, changeset} -> {:error, "Failed to create enrollment: #{inspect(changeset.errors)}"}
    end
  end

  defp update_group_user_batch(user_id, new_batch_group_id) do
    # Find existing batch group user record
    batch_group_user =
      from(gu in Dbservice.Groups.GroupUser,
        join: g in Groups.Group,
        on: g.id == gu.group_id and g.type == "batch",
        where: gu.user_id == ^user_id
      )
      |> Repo.one()

    case batch_group_user do
      nil ->
        # Create new group user record if none exists
        create_attrs = %{
          user_id: user_id,
          group_id: new_batch_group_id
        }

        case GroupUsers.create_group_user(create_attrs) do
          {:ok, group_user} -> {:ok, group_user}
          {:error, changeset} -> {:error, "Failed to create group user: #{inspect(changeset.errors)}"}
        end

      existing_group_user ->
        # Update existing group user with new batch group
        case GroupUsers.update_group_user(existing_group_user, %{group_id: new_batch_group_id}) do
          {:ok, group_user} -> {:ok, group_user}
          {:error, changeset} -> {:error, "Failed to update group user: #{inspect(changeset.errors)}"}
        end
    end
  end
end
