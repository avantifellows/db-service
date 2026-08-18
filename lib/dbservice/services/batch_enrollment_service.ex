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
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Statuses.Status
  alias Dbservice.Grades.Grade
  alias Dbservice.Users

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

    # End only the current batch enrollments in the SAME program as the target
    # batch, so a student enrolled in batches of other programs keeps those ERs.
    # This mirrors the program-scoped group_user reconcile in update_batch_user/2
    # — ending batch ERs globally here while leaving other-program memberships
    # intact would recreate the ER/group_user mismatch this PR fixes (issue #656
    # review; see the "other programs ... must remain unchanged" rule in CLAUDE.md).
    end_current_batch_enrollments_in_program(user_id, batch_id, start_date)
    EnrollmentRecords.create_enrollment_record(new_enrollment_attrs)
  end

  # Ends the user's current "batch" enrollment records whose batch shares the
  # target batch's program (nil program is its own scope), leaving current batch
  # enrollments in other programs untouched. enrollment_record.group_id for a
  # batch is the batch id (group.child_id).
  defp end_current_batch_enrollments_in_program(user_id, target_batch_id, start_date) do
    same_program_batch_ids = batch_ids_in_same_program(target_batch_id)

    from(e in EnrollmentRecord,
      where:
        e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
          e.group_id in ^same_program_batch_ids,
      update: [set: [is_current: false, end_date: ^start_date]]
    )
    |> Repo.update_all([])
  end

  defp batch_ids_in_same_program(target_batch_id) do
    program_id = Repo.one(from(b in Batch, where: b.id == ^target_batch_id, select: b.program_id))
    batch_ids_for_program(program_id)
  end

  defp batch_ids_for_program(nil) do
    Repo.all(from(b in Batch, where: is_nil(b.program_id), select: b.id))
  end

  defp batch_ids_for_program(program_id) do
    Repo.all(from(b in Batch, where: b.program_id == ^program_id, select: b.id))
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
  Fetches grade information based on the grade number.
  Returns {grade_group_id, grade_id, grade_group_type}
  """
  def get_grade_info(grade_number) do
    from(gr in Grade,
      join: g in Group,
      on: g.child_id == gr.id and g.type == "grade",
      where: gr.number == ^grade_number,
      select: {g.id, g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Handles grade enrollment process
  """
  def handle_grade_enrollment(user_id, grade_id, grade_group_type, academic_year, start_date) do
    new_grade_enrollment_attrs = %{
      user_id: user_id,
      is_current: true,
      start_date: start_date,
      group_id: grade_id,
      group_type: grade_group_type,
      academic_year: academic_year
    }

    # Update existing grade enrollments to mark them as not current
    update_existing_enrollments(user_id, "grade", start_date)
    EnrollmentRecords.create_enrollment_record(new_grade_enrollment_attrs)
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
  Reconciles the batch group_user memberships for a user after a batch move.

  Scoped to the *target batch's program*, so a student legitimately enrolled in
  batches of other programs keeps those memberships. Within the program it
  collapses the batch memberships to exactly one row pointing at `group_id`,
  deleting any stale/duplicate batch group_user rows. This is the fix for the
  duplicate-batch-membership bug: the previous `Enum.find` repointed only the
  first matching row and left the rest behind.

  Scoping is queried directly from the batch/type joins, so no caller-supplied
  membership list is needed.
  """
  def update_batch_user(user_id, group_id) do
    case batch_for_group_id(group_id) do
      nil ->
        GroupUsers.create_group_user(%{user_id: user_id, group_id: group_id})

      new_batch ->
        user_id
        |> batch_group_users_in_program(new_batch.program_id)
        |> reconcile_group_user(user_id, group_id)
    end
  end

  @doc """
  Reconciles the grade group_user membership for a user.

  Grade is an exclusive membership type, so this collapses *all* of the user's
  grade group_user rows to exactly one pointing at `grade_group_id`.
  """
  def update_grade_user(user_id, grade_group_id) do
    user_id
    |> grade_group_users()
    |> reconcile_group_user(user_id, grade_group_id)
  end

  # Resolves the batch behind a "batch"-type group id (returns %Batch{} or nil).
  defp batch_for_group_id(group_id) do
    from(g in Group,
      join: b in Batch,
      on: b.id == g.child_id,
      where: g.id == ^group_id and g.type == "batch",
      select: b
    )
    |> Repo.one()
  end

  defp batch_group_users_in_program(user_id, nil) do
    from(gu in GroupUser,
      join: g in Group,
      on: g.id == gu.group_id and g.type == "batch",
      join: b in Batch,
      on: b.id == g.child_id,
      where: gu.user_id == ^user_id and is_nil(b.program_id),
      order_by: [asc: gu.inserted_at, asc: gu.id]
    )
    |> Repo.all()
  end

  defp batch_group_users_in_program(user_id, program_id) do
    from(gu in GroupUser,
      join: g in Group,
      on: g.id == gu.group_id and g.type == "batch",
      join: b in Batch,
      on: b.id == g.child_id,
      where: gu.user_id == ^user_id and b.program_id == ^program_id,
      order_by: [asc: gu.inserted_at, asc: gu.id]
    )
    |> Repo.all()
  end

  defp grade_group_users(user_id) do
    from(gu in GroupUser,
      join: g in Group,
      on: g.id == gu.group_id and g.type == "grade",
      where: gu.user_id == ^user_id,
      order_by: [asc: gu.inserted_at, asc: gu.id]
    )
    |> Repo.all()
  end

  # Collapses the (already scoped) `existing` group_user rows to exactly one row
  # pointing at `target_group_id`, deleting the rest. Prefers reusing a row that
  # already points at the target.
  defp reconcile_group_user(existing, user_id, target_group_id) do
    case Enum.split_with(existing, &(&1.group_id == target_group_id)) do
      {[keep | dup_matches], others} ->
        Enum.each(dup_matches ++ others, &GroupUsers.delete_group_user/1)
        {:ok, keep}

      {[], [keep | drop]} ->
        Enum.each(drop, &GroupUsers.delete_group_user/1)
        GroupUsers.update_group_user(keep, %{group_id: target_group_id})

      {[], []} ->
        GroupUsers.create_group_user(%{user_id: user_id, group_id: target_group_id})
    end
  end

  @doc """
  Updates grade in student table
  """
  def update_student_grade(student, grade_id) do
    Users.update_student(student, %{"grade_id" => grade_id})
  end

  @doc """
  Checks if grade has changed by comparing current grade with new grade
  """
  def grade_changed?(user_id, new_grade_id) do
    current_grade = EnrollmentRecords.get_current_grade_id(user_id)
    current_grade != new_grade_id
  end
end
