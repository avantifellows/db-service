defmodule Dbservice.Services.DropoutService do
  @moduledoc """
  Shared service for handling student dropout operations.
  This module contains reusable functions for dropout logic
  used in student controller and dropout imports.
  """

  import Ecto.Query
  alias Dbservice.Batches.Batch
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  alias Dbservice.GroupUsers
  alias Dbservice.LmsStudentIngestion
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Repo
  alias Dbservice.Schools.School
  alias Dbservice.Statuses.Status
  alias Dbservice.Users

  @audit_action "student_program_dropout"
  @undo_audit_action "student_program_dropout_undo"
  @nvs_program_id 64

  @doc """
  Fetches dropout status information.
  Returns {status_id, status_group_type}
  """
  def get_dropout_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :dropout,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Processes student dropout by updating enrollments and student status.
  Returns {:ok, student} on success or {:error, reason} on failure.
  """
  def process_dropout(student, start_date, academic_year, audit_params \\ %{}) do
    dropout_transaction(student, start_date, academic_year, audit_params)
  end

  defp dropout_transaction(student, start_date, academic_year, audit_params) do
    Repo.transaction(fn ->
      with {:ok, student} <- lock_student(student.id),
           :ok <- validate_dropout_status(student),
           :ok <- validate_academic_year(student, academic_year, audit_params),
           :ok <- validate_lms_audit_params(student, audit_params),
           {:ok, updated_student} <-
             create_dropout_with_audit(student, start_date, academic_year, audit_params) do
        updated_student
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp lock_student(student_id) do
    case from(s in Dbservice.Users.Student, where: s.id == ^student_id, lock: "FOR UPDATE")
         |> Repo.one() do
      nil -> {:error, "Student not found"}
      student -> {:ok, student}
    end
  end

  defp validate_dropout_status(%{status: "dropout"}),
    do: {:error, "Student is already marked as dropout"}

  defp validate_dropout_status(_student), do: :ok

  # Guards against stamping a dropout with an academic year that does not match
  # the enrollment actually being ended. The academic year is caller-supplied
  # (dropout API param / CSV column), so a wrong value silently attributes the
  # dropout to the wrong year (the Wardha bug), or for a multi-program student to
  # a different program's year than the one being dropped.
  #
  # When the request targets a specific program (LMS/portal path carrying a
  # program_id), validate against that program's current enrollment year. For a
  # plain/bulk dropout that ends every current enrollment, validate against the
  # student's most recent current academic year. When there is no current
  # enrollment to compare against, there is nothing to validate and we allow it.
  defp validate_academic_year(student, academic_year, audit_params) do
    expected_years =
      if lms_program_dropout?(audit_params) do
        program_academic_years(student.user_id, audit_params["program_id"])
      else
        most_recent_academic_years(student.user_id)
      end

    cond do
      expected_years == [] -> :ok
      academic_year in expected_years -> :ok
      true -> {:error, academic_year_mismatch_error(academic_year, expected_years)}
    end
  end

  defp academic_year_mismatch_error(academic_year, expected_years) do
    "Academic year mismatch: provided #{inspect(academic_year)} but the student's " <>
      "current enrollment is for #{Enum.join(expected_years, ", ")}"
  end

  # Academic year(s) of the student's current batch enrollment in a specific
  # program. Empty when the student has no current batch in that program, in
  # which case create_program_dropout surfaces the "not enrolled" error instead.
  defp program_academic_years(user_id, program_id) do
    from(e in EnrollmentRecord,
      join: b in Batch,
      on: b.id == e.group_id,
      where:
        e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
          b.program_id == ^program_id and not is_nil(e.academic_year),
      distinct: true,
      select: e.academic_year
    )
    |> Repo.all()
  end

  # Most recent academic year across the student's current enrollments, as a
  # single-element list (or [] when none carry an academic year).
  defp most_recent_academic_years(user_id) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.is_current == true and not is_nil(e.academic_year),
      order_by: [desc: e.academic_year],
      limit: 1,
      select: e.academic_year
    )
    |> Repo.all()
  end

  defp create_dropout_with_audit(student, start_date, academic_year, audit_params) do
    dropout_result =
      if lms_program_dropout?(audit_params) do
        create_program_dropout(student, start_date, academic_year, audit_params["program_id"])
      else
        case create_dropout_enrollment(student, start_date, academic_year) do
          {:ok, updated_student} -> {:ok, updated_student, nil, nil}
          error -> error
        end
      end

    with {:ok, updated_student, program_enrollment, global_restore} <- dropout_result,
         {:ok, _audit} <-
           maybe_insert_lms_audit(
             student,
             updated_student,
             program_enrollment,
             global_restore,
             start_date,
             academic_year,
             audit_params
           ) do
      {:ok, updated_student}
    end
  end

  defp lms_program_dropout?(params) do
    is_map(params["actor"]) and is_map(params["school"])
  end

  defp create_program_dropout(student, start_date, academic_year, program_id) do
    enrollments = current_program_enrollments(student.user_id, program_id)

    case enrollments do
      [] ->
        {:error, "Student is not currently enrolled in this program"}

      [enrollment] ->
        with {1, nil} <- end_program_enrollment(enrollment, start_date),
             {1, nil} <- delete_program_group_user(student.user_id, enrollment.group_id) do
          finish_program_dropout(student, enrollment, start_date, academic_year)
        else
          _ -> {:error, "Failed to end program enrollment"}
        end

      _multiple ->
        {:error, "Student has multiple current batches in this program"}
    end
  end

  defp finish_program_dropout(student, enrollment, start_date, academic_year) do
    if current_batch_count(student.user_id) > 0 do
      {:ok, student, enrollment, nil}
    else
      ended_enrollment_ids = current_enrollment_ids(student.user_id)

      case create_dropout_enrollment(student, start_date, academic_year) do
        {:ok, updated_student} ->
          {:ok, updated_student, enrollment,
           %{
             "ended_enrollment_ids" => ended_enrollment_ids,
             "dropout_status_enrollment_id" => current_dropout_enrollment_id(student.user_id)
           }}

        {:error, _reason} ->
          {:error, "Failed to process dropout"}
      end
    end
  end

  defp current_enrollment_ids(user_id) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.is_current == true,
      select: e.id
    )
    |> Repo.all()
  end

  defp current_dropout_enrollment_id(user_id) do
    {dropout_status_id, _} = get_dropout_status_info()

    from(e in EnrollmentRecord,
      where:
        e.user_id == ^user_id and e.group_type == "status" and
          e.group_id == ^dropout_status_id and e.is_current == true,
      select: e.id
    )
    |> Repo.one()
  end

  defp current_program_enrollments(user_id, program_id) do
    from(e in EnrollmentRecord,
      join: b in Batch,
      on: b.id == e.group_id,
      where:
        e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
          b.program_id == ^program_id
    )
    |> lock("FOR UPDATE")
    |> Repo.all()
  end

  defp end_program_enrollment(enrollment, end_date) do
    from(e in EnrollmentRecord,
      where: e.id == ^enrollment.id,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end

  defp delete_program_group_user(user_id, batch_id) do
    from(gu in GroupUser,
      join: g in Group,
      on: g.id == gu.group_id,
      where: gu.user_id == ^user_id and g.type == "batch" and g.child_id == ^batch_id
    )
    |> Repo.delete_all()
  end

  defp current_batch_count(user_id) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true,
      select: count(e.id)
    )
    |> Repo.one()
  end

  defp create_dropout_enrollment(student, start_date, academic_year) do
    case get_dropout_status_info() do
      nil ->
        {:error, "Dropout status not found in the system"}

      {status_id, group_type} ->
        user_id = student.user_id
        update_current_enrollments(user_id, start_date)

        new_enrollment_attrs =
          build_enrollment_attrs(student, status_id, group_type, start_date, academic_year)

        with {:ok, _enrollment_record} <-
               EnrollmentRecords.create_enrollment_record(new_enrollment_attrs),
             {:ok, updated_student} <-
               Users.update_student(student, %{"status" => "dropout"}) do
          {:ok, updated_student}
        else
          {:error, changeset} ->
            {:error, format_dropout_error(changeset)}
        end
    end
  end

  defp build_enrollment_attrs(student, status_id, group_type, start_date, academic_year) do
    %{
      user_id: student.user_id,
      is_current: true,
      start_date: start_date,
      group_id: status_id,
      group_type: group_type,
      academic_year: academic_year,
      grade_id: student.grade_id
    }
  end

  defp maybe_insert_lms_audit(
         _student,
         _updated_student,
         _program_enrollment,
         _global_restore,
         _start_date,
         _academic_year,
         params
       )
       when params == %{},
       do: {:ok, nil}

  defp maybe_insert_lms_audit(
         _student,
         _updated_student,
         _program_enrollment,
         _global_restore,
         _start_date,
         _academic_year,
         params
       )
       when not is_map_key(params, "actor") or not is_map_key(params, "school"),
       do: {:ok, nil}

  defp maybe_insert_lms_audit(
         student,
         updated_student,
         program_enrollment,
         global_restore,
         start_date,
         academic_year,
         params
       ) do
    audit_changeset =
      LmsStudentWriteAudit.changeset(%LmsStudentWriteAudit{}, %{
        action: @audit_action,
        actor_user_id: get_in(params, ["actor", "user_id"]),
        actor_email: get_in(params, ["actor", "email"]),
        actor_login_type: get_in(params, ["actor", "login_type"]),
        actor_role: get_in(params, ["actor", "role"]),
        school_code: get_in(params, ["school", "code"]),
        school_udise_code: get_in(params, ["school", "udise_code"]),
        program_id: params["program_id"],
        row_counts: %{},
        affected_identifiers: %{
          "student_pk_id" => student.id,
          "user_id" => student.user_id,
          "student_id" => student.student_id,
          "pen_number" => student.pen_number,
          "apaar_id" => student.apaar_id
        },
        changed_values:
          %{
            "status" => %{"old" => student.status, "new" => updated_student.status},
            "dropout_date" => %{"old" => nil, "new" => start_date},
            "academic_year" => %{"old" => nil, "new" => academic_year}
          }
          |> Map.merge(program_enrollment_changes(program_enrollment, start_date))
          |> Map.merge(global_restore_changes(global_restore))
      })

    case Repo.insert(audit_changeset) do
      {:ok, audit} -> {:ok, audit}
      {:error, _changeset} -> {:error, "Failed to write dropout audit"}
    end
  end

  defp program_enrollment_changes(nil, _start_date), do: %{}

  defp program_enrollment_changes(enrollment, start_date) do
    %{
      "batch_enrollment_id" => %{"old" => enrollment.id, "new" => nil},
      "batch_id" => %{"old" => enrollment.group_id, "new" => nil},
      "batch_enrollment_is_current" => %{"old" => true, "new" => false},
      "batch_enrollment_end_date" => %{"old" => enrollment.end_date, "new" => start_date}
    }
  end

  defp global_restore_changes(nil), do: %{}

  defp global_restore_changes(restore) do
    %{
      "ended_enrollment_ids" => %{"old" => restore["ended_enrollment_ids"], "new" => []},
      "dropout_status_enrollment_id" => %{
        "old" => nil,
        "new" => restore["dropout_status_enrollment_id"]
      }
    }
  end

  defp validate_lms_audit_params(_student, params) when params == %{}, do: :ok

  defp validate_lms_audit_params(_student, params)
       when not is_map_key(params, "actor") and not is_map_key(params, "school") and
              not is_map_key(params, "program_id"),
       do: :ok

  defp validate_lms_audit_params(student, %{"actor" => actor, "school" => school} = params)
       when is_map(actor) and is_map(school) do
    case params["program_id"] do
      program_id when is_integer(program_id) ->
        if program_id == @nvs_program_id and
             not LmsStudentIngestion.current_nvs_program?(program_id) do
          {:error, "Program must be a current NVS program"}
        else
          validate_lms_school(student, school)
        end

      _ ->
        {:error, "Invalid program_id"}
    end
  end

  defp validate_lms_audit_params(_student, _params), do: {:error, "Invalid LMS audit metadata"}

  defp validate_lms_school(student, school) do
    case current_school(student.user_id) do
      %{code: code, udise_code: udise_code} ->
        if school["code"] == code and school["udise_code"] == udise_code,
          do: :ok,
          else: {:error, "Student is not enrolled in this school"}

      _school ->
        {:error, "Student is not enrolled in this school"}
    end
  end

  @doc "Restores the exact NVS enrollment ended by a recent audited LMS dropout."
  def undo_program_dropout(student, params) do
    Repo.transaction(fn ->
      with {:ok, student} <- lock_student(student.id),
           :ok <- validate_undo_params(params),
           {:ok, audit} <- undoable_dropout_audit(student, params),
           {:ok, enrollment, batch} <- validate_undo_target(student, audit),
           :ok <- validate_undo_school(student, audit),
           :ok <- restore_dropout(student, enrollment, batch, audit),
           {:ok, _audit} <- insert_undo_audit(student, audit, params) do
        Repo.get!(Dbservice.Users.Student, student.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp validate_undo_params(%{
         "actor" => actor,
         "school" => school,
         "program_id" => @nvs_program_id
       })
       when is_map(actor) and is_map(school),
       do: :ok

  defp validate_undo_params(_params), do: {:error, "Invalid LMS audit metadata"}

  defp undoable_dropout_audit(student, params) do
    audits =
      from(a in LmsStudentWriteAudit,
        where:
          a.action in [@audit_action, @undo_audit_action] and
            fragment("? ->> 'student_pk_id' = ?", a.affected_identifiers, ^to_string(student.id)),
        order_by: [desc: a.id]
      )
      |> Repo.all()

    undone_ids =
      audits
      |> Enum.filter(&(&1.action == @undo_audit_action))
      |> Enum.map(&get_in(&1.affected_identifiers, ["dropout_audit_id"]))
      |> MapSet.new()

    audit =
      Enum.find(audits, fn audit ->
        audit.action == @audit_action and audit.program_id == @nvs_program_id and
          audit.school_code == get_in(params, ["school", "code"]) and
          not MapSet.member?(undone_ids, audit.id) and
          is_integer(get_in(audit.changed_values, ["batch_enrollment_id", "old"]))
      end)

    if audit, do: {:ok, audit}, else: {:error, "This dropout cannot be undone"}
  end

  defp validate_undo_target(student, audit) do
    enrollment_id = get_in(audit.changed_values, ["batch_enrollment_id", "old"])

    enrollment =
      Repo.get_by(EnrollmentRecord,
        id: enrollment_id,
        user_id: student.user_id,
        group_type: "batch",
        is_current: false
      )

    batch = enrollment && Repo.get(Batch, enrollment.group_id)

    cond do
      is_nil(enrollment) or is_nil(batch) ->
        {:error, "The previous NVS batch no longer exists"}

      batch.program_id != @nvs_program_id ->
        {:error, "The previous enrollment is not an NVS batch"}

      batch.end_date && Date.compare(batch.end_date, Date.utc_today()) == :lt ->
        {:error, "The previous NVS batch is closed"}

      current_program_enrollments(student.user_id, @nvs_program_id) != [] ->
        {:error, "Student already has an active NVS batch"}

      true ->
        {:ok, enrollment, batch}
    end
  end

  defp validate_undo_school(student, audit) do
    latest_school_code =
      from(e in EnrollmentRecord,
        join: s in School,
        on: s.id == e.group_id,
        where: e.user_id == ^student.user_id and e.group_type == "school",
        order_by: [desc: e.is_current, desc: e.updated_at, desc: e.id],
        select: s.code,
        limit: 1
      )
      |> Repo.one()

    if latest_school_code == audit.school_code,
      do: :ok,
      else: {:error, "Student is no longer in the same school"}
  end

  defp restore_dropout(student, enrollment, batch, audit) do
    global_ids = get_in(audit.changed_values, ["ended_enrollment_ids", "old"]) || []
    dropout_status_id = get_in(audit.changed_values, ["dropout_status_enrollment_id", "new"])

    with {1, nil} <-
           from(e in EnrollmentRecord, where: e.id == ^enrollment.id)
           |> Repo.update_all(set: [is_current: true, end_date: nil]),
         :ok <- restore_global_enrollments(student, global_ids, dropout_status_id),
         :ok <- restore_batch_group_user(student.user_id, batch.id) do
      restore_student_status(student, audit, global_ids)
    else
      _ -> {:error, "Failed to restore the previous NVS enrollment"}
    end
  end

  defp restore_global_enrollments(_student, [], nil), do: :ok

  defp restore_global_enrollments(student, enrollment_ids, dropout_status_id)
       when is_list(enrollment_ids) and is_integer(dropout_status_id) do
    {restored, nil} =
      from(e in EnrollmentRecord,
        where: e.user_id == ^student.user_id and e.id in ^enrollment_ids and e.is_current == false
      )
      |> Repo.update_all(set: [is_current: true, end_date: nil])

    {ended_dropout, nil} =
      from(e in EnrollmentRecord,
        where:
          e.id == ^dropout_status_id and e.user_id == ^student.user_id and e.is_current == true
      )
      |> Repo.update_all(set: [is_current: false, end_date: Date.utc_today()])

    if restored == length(enrollment_ids) and ended_dropout == 1,
      do: :ok,
      else: {:error, "Failed to restore the student's previous enrollments"}
  end

  defp restore_global_enrollments(_student, _ids, _status_id),
    do: {:error, "This dropout cannot be safely undone"}

  defp restore_batch_group_user(user_id, batch_id) do
    case Repo.get_by(Group, type: "batch", child_id: batch_id) do
      nil ->
        {:error, "The previous NVS batch no longer exists"}

      group ->
        case Repo.get_by(GroupUser, user_id: user_id, group_id: group.id) do
          nil ->
            case GroupUsers.create_group_user(%{user_id: user_id, group_id: group.id}) do
              {:ok, _} -> :ok
              _ -> {:error, "Failed to restore batch membership"}
            end

          _existing ->
            :ok
        end
    end
  end

  defp restore_student_status(_student, _audit, []), do: :ok

  defp restore_student_status(student, audit, _global_ids) do
    old_status = get_in(audit.changed_values, ["status", "old"])

    case Users.update_student(student, %{"status" => old_status}) do
      {:ok, _} -> :ok
      _ -> {:error, "Failed to restore student status"}
    end
  end

  defp insert_undo_audit(student, dropout_audit, params) do
    LmsStudentWriteAudit.changeset(%LmsStudentWriteAudit{}, %{
      action: @undo_audit_action,
      actor_user_id: get_in(params, ["actor", "user_id"]),
      actor_email: get_in(params, ["actor", "email"]),
      actor_login_type: get_in(params, ["actor", "login_type"]),
      actor_role: get_in(params, ["actor", "role"]),
      school_code: dropout_audit.school_code,
      school_udise_code: dropout_audit.school_udise_code,
      program_id: @nvs_program_id,
      row_counts: %{},
      affected_identifiers: %{
        "student_pk_id" => student.id,
        "user_id" => student.user_id,
        "student_id" => student.student_id,
        "pen_number" => student.pen_number,
        "apaar_id" => student.apaar_id,
        "dropout_audit_id" => dropout_audit.id
      },
      changed_values: %{
        "batch_id" => %{
          "old" => nil,
          "new" => get_in(dropout_audit.changed_values, ["batch_id", "old"])
        },
        "status" => %{
          "old" => student.status,
          "new" => get_in(dropout_audit.changed_values, ["status", "old"])
        }
      }
    })
    |> Repo.insert()
  end

  defp current_school(user_id) do
    from(e in EnrollmentRecord,
      join: s in School,
      on: s.id == e.group_id,
      where: e.user_id == ^user_id and e.group_type == "school" and e.is_current == true,
      select: s,
      limit: 1
    )
    |> Repo.one()
  end

  defp format_dropout_error(changeset) do
    if changeset.errors != [] do
      "Failed to process dropout: #{inspect(changeset.errors)}"
    else
      "Failed to process dropout"
    end
  end

  @doc """
  Updates all current enrollment records for a user to mark them as not current.
  Sets is_current=false and end_date for all current enrollments.
  """
  def update_current_enrollments(user_id, end_date) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.is_current == true,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end
end
