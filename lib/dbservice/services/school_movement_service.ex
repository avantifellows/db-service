defmodule Dbservice.Services.SchoolMovementService do
  @moduledoc """
  Moves a student to a new school while preserving enrollment history.

  Unlike `Dbservice.Services.GroupUpdateService` (used by the
  `update_incorrect_school_to_correct_school` import), which mutates the current
  school enrollment in place and therefore loses the previous school, this
  service:

    * closes out the student's current school enrollment(s) by setting
      `is_current: false` and stamping `end_date` — the row is kept, not deleted,
      so the history of which school the student attended is preserved;
    * inserts a new `is_current: true` school enrollment for the target academic
      year (reactivating an existing row for the same school/year if one already
      exists, so re-running an import is idempotent);
    * swaps the single `group_user` membership row for the "school" group type
      (that table has no history concept and always reflects the current school).

  Enrollment records for other academic years (already `is_current: false`) are
  left untouched. The whole operation runs in a transaction.

  Note the two `group_id` conventions: `enrollment_record.group_id` stores the
  child entity id (`school.id`, i.e. `group.child_id`), while `group_user.group_id`
  stores the groups-table primary key (`group.id`).
  """

  import Ecto.Query, warn: false

  alias Dbservice.Repo
  alias Dbservice.Groups
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  alias Dbservice.GroupUsers
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  @school_group_type "school"

  @doc """
  Moves a student to a new school, preserving the previous school as history.

  Expects a params map with:
    * `"user_id"` - the student's user id
    * `"group_id"` - the groups-table PK of the target (correct) school group
    * `"academic_year"` - the academic year the new enrollment applies to
    * `"effective_date"` - optional ISO8601 date string; defaults to today

  Returns `{:ok, %EnrollmentRecord{}}` or `{:error, reason}`.
  """
  def move_student_school(%{"user_id" => user_id, "group_id" => group_id} = params) do
    academic_year = params["academic_year"]

    with {:ok, effective_date} <- parse_effective_date(params["effective_date"]) do
      school_group = Groups.get_group!(group_id)

      Repo.transaction(fn ->
        # Close out the student's current school enrollment(s), preserving them as
        # history. Rows for other years are already is_current: false, so untouched.
        close_out_current_school_enrollments(user_id, effective_date)

        with {:ok, enrollment} <-
               upsert_school_enrollment(
                 user_id,
                 school_group.child_id,
                 academic_year,
                 effective_date
               ),
             {:ok, _group_user} <- swap_school_group_user(user_id, group_id) do
          enrollment
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  defp close_out_current_school_enrollments(user_id, end_date) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_type == ^@school_group_type and
          er.is_current == true,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end

  defp upsert_school_enrollment(user_id, school_id, academic_year, start_date) do
    case get_school_enrollment(user_id, school_id, academic_year) do
      nil ->
        EnrollmentRecords.create_enrollment_record(%{
          "user_id" => user_id,
          "group_id" => school_id,
          "group_type" => @school_group_type,
          "academic_year" => academic_year,
          "start_date" => start_date,
          "is_current" => true
        })

      %EnrollmentRecord{} = record ->
        # A record for this school/year already exists (e.g. a re-run) — reactivate
        # it rather than inserting a duplicate.
        EnrollmentRecords.update_enrollment_record(record, %{
          "is_current" => true,
          "start_date" => start_date,
          "end_date" => nil
        })
    end
  end

  defp get_school_enrollment(user_id, school_id, academic_year) do
    Repo.one(
      from er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_id == ^school_id and
            er.group_type == ^@school_group_type and
            er.academic_year == ^academic_year,
        order_by: [desc: er.id],
        limit: 1
    )
  end

  # Mirrors the group_user handling in ReEnrollmentService: group_user carries no
  # history, so all school-type memberships for the user are removed and a single
  # fresh one is created for the new school group.
  defp swap_school_group_user(user_id, group_id) do
    group = Groups.get_group!(group_id)

    group_ids_subquery =
      from(g in Group, where: g.type == ^group.type, select: g.id)

    from(gu in GroupUser,
      where: gu.user_id == ^user_id and gu.group_id in subquery(group_ids_subquery)
    )
    |> Repo.delete_all()

    GroupUsers.create_group_user(%{"user_id" => user_id, "group_id" => group_id})
  end

  defp parse_effective_date(nil), do: {:ok, Date.utc_today()}
  defp parse_effective_date(""), do: {:ok, Date.utc_today()}
  defp parse_effective_date(%Date{} = date), do: {:ok, date}

  defp parse_effective_date(date) when is_binary(date) do
    case Date.from_iso8601(String.trim(date)) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "Invalid effective_date: #{date}. Expected format YYYY-MM-DD"}
    end
  end
end
