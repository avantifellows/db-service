defmodule Dbservice.Services.BatchEnrollmentService do
  @moduledoc """
  Shared service for handling batch enrollment operations.
  This module contains reusable functions for batch enrollment logic
  used in student controller and batch movement imports.
  """

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.GroupUsers
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group
  alias Dbservice.Statuses.Status

  @doc """
  Fetches batch information based on the batch ID.
  Returns {batch_group_id, batch_id, batch_group_type}
  """
  def get_batch_info(batch_id) do
    from(b in Batch,
      join: g in Group,
      on: g.child_id == b.id and g.type == "batch",
      where: b.batch_id == ^batch_id,
      select: {g.id, g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Fetches enrolled status information.
  Returns {status_id, status_group_type}
  """
  def get_enrolled_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :enrolled,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Checks if the student is already enrolled in the batch
  """
  def existing_batch_enrollment?(user_id, batch_id) do
    from(e in EnrollmentRecord,
      where:
        e.user_id == ^user_id and e.group_id == ^batch_id and e.group_type == "batch" and
          e.is_current == true
    )
    |> Repo.exists?()
  end

  @doc """
  Handles batch enrollment process
  """
  def handle_batch_enrollment(user_id, batch_id, group_type, academic_year, start_date) do
    new_enrollment_attrs = %{
      user_id: user_id,
      is_current: true,
      start_date: start_date,
      group_id: batch_id,
      group_type: group_type,
      academic_year: academic_year
    }

    # Update existing enrollments to mark them as not current
    update_existing_enrollments(user_id, "batch", start_date)
    EnrollmentRecords.create_enrollment_record(new_enrollment_attrs)
  end

  @doc """
  Handles status enrollment process
  """
  def handle_status_enrollment(user_id, status_id, status_group_type, academic_year, start_date) do
    new_status_enrollment_attrs = %{
      user_id: user_id,
      is_current: true,
      start_date: start_date,
      group_id: status_id,
      group_type: status_group_type,
      academic_year: academic_year
    }

    # Update existing enrollments to mark them as not current
    update_existing_enrollments(user_id, "status", start_date)
    EnrollmentRecords.create_enrollment_record(new_status_enrollment_attrs)
  end

  @doc """
  Updates existing enrollments to mark them as not current
  """
  def update_existing_enrollments(user_id, group_type, start_date) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true,
      update: [set: [is_current: false, end_date: ^start_date]]
    )
    |> Repo.update_all([])
  end

  @doc """
  Updates or creates a group user record for the batch
  """
  def update_batch_user(user_id, group_id, group_users) do
    batch_group_user = Enum.find(group_users, &group_user_by_type?(&1, "batch"))

    if batch_group_user do
      # Update existing group user with the new group ID
      GroupUsers.update_group_user(batch_group_user, %{group_id: group_id})
    else
      # Create a new group user record
      GroupUsers.create_group_user(%{user_id: user_id, group_id: group_id})
    end
  end

  @doc """
  Checks if a group user is associated with a specific type
  """
  def group_user_by_type?(group_user, type) do
    from(g in Group,
      where: g.id == ^group_user.group_id and g.type == ^type,
      select: g.id
    )
    |> Repo.exists?()
  end
end
