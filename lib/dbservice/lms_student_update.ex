defmodule Dbservice.LmsStudentUpdate do
  @moduledoc """
  Atomic LMS student correction flow.

  Grade changes here are corrections to bad current data. They are not the annual
  Grade 11 -> Grade 12 promotion flow, where the G12 graduating year stays stable.
  """

  import Ecto.Query

  alias Dbservice.Batches.Batch
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Grades
  alias Dbservice.GroupUsers
  alias Dbservice.Groups
  alias Dbservice.Groups.GroupUser
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Users
  alias Dbservice.Users.Student

  @action "student_update"
  @cbse_board "CENTRAL BOARD OF SECONDARY EDUCATION"
  @user_fields ["first_name", "last_name", "gender", "date_of_birth", "phone"]
  @student_fields [
    "category",
    "physically_handicapped",
    "board_stream",
    "stream",
    "father_name",
    "annual_family_income",
    "g10_board"
  ]
  @locked_fields [
    "apaar_id",
    "auth_group",
    "batch_group_id",
    "batch_id",
    "g10_roll_no",
    "grade_id",
    "group_id",
    "school_code",
    "student_id",
    "udise_code",
    "user_id"
  ]
  @metadata_fields ["actor", "school", "program_id", "academic_year", "start_date"]
  @editable_fields @user_fields ++ @student_fields ++ ["grade"]

  def update(student_pk_id, params) do
    Repo.transaction(fn ->
      with :ok <- reject_locked_fields(params),
           :ok <- reject_unsupported_fields(params),
           {:ok, student} <- fetch_student(student_pk_id),
           {:ok, school} <- fetch_school(params),
           :ok <- validate_school_scope(student, school, params["program_id"]),
           {:ok, user} <- fetch_user(student),
           :ok <- validate_g10_board(student, params),
           {:ok, plan} <- enrollment_plan(student, params),
           {:ok, changed_values} <- changed_values(user, student, params, plan),
           {:ok, user} <- update_user(user, params),
           {:ok, student} <- update_student(student, params, plan),
           {:ok, _enrollments} <- replace_enrollments(student.user_id, plan, params),
           {:ok, audit} <- insert_audit(user, student, school, params, changed_values) do
        %{
          "status" => "updated",
          "student_pk_id" => student.id,
          "changed_fields" => changed_values |> Map.keys() |> Enum.sort(),
          "audit_id" => audit.id
        }
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp reject_locked_fields(params) do
    case params |> Map.keys() |> Enum.filter(&(&1 in @locked_fields)) |> Enum.sort() do
      [] -> :ok
      fields -> {:error, error("locked_fields", "Locked fields cannot be updated", 422, fields)}
    end
  end

  defp reject_unsupported_fields(params) do
    allowed = @metadata_fields ++ @editable_fields

    case params |> Map.keys() |> Enum.reject(&(&1 in allowed)) |> Enum.sort() do
      [] ->
        :ok

      fields ->
        {:error, error("unsupported_fields", "Unsupported fields cannot be updated", 422, fields)}
    end
  end

  defp fetch_student(id) do
    case Repo.get(Student, id) do
      nil -> {:error, error("not_found", "Student not found", 404)}
      student -> {:ok, student}
    end
  end

  defp fetch_school(%{"school" => %{"code" => code, "udise_code" => udise_code}}) do
    case Schools.get_school_by_code(code) do
      %{udise_code: ^udise_code} = school -> {:ok, school}
      _ -> {:error, error("school_not_found", "School not found", 404)}
    end
  end

  defp fetch_school(_params), do: {:error, error("school_required", "School is required", 400)}

  defp validate_school_scope(student, school, program_id) do
    cond do
      to_int(program_id) not in (school.program_ids || []) ->
        {:error, error("program_not_allowed", "School is not eligible for this program", 403)}

      not enrolled?(student.user_id, school.id, "school") ->
        {:error, error("school_mismatch", "Student is not enrolled in this school", 403)}

      true ->
        :ok
    end
  end

  defp enrolled?(user_id, group_id, group_type) do
    from(e in EnrollmentRecord,
      where:
        e.user_id == ^user_id and e.group_id == ^group_id and e.group_type == ^group_type and
          e.is_current == true
    )
    |> Repo.exists?()
  end

  defp fetch_user(student) do
    {:ok, Users.get_user!(student.user_id)}
  rescue
    Ecto.NoResultsError -> {:error, error("user_not_found", "Student user not found", 404)}
  end

  defp validate_g10_board(_student, params) when not is_map_key(params, "g10_board"), do: :ok

  defp validate_g10_board(student, %{"g10_board" => @cbse_board}) do
    if student.g10_roll_no in [nil, ""] or Regex.match?(~r/^\d{8}$/, student.g10_roll_no) do
      :ok
    else
      {:error,
       error(
         "invalid_g10_roll_for_board",
         "CBSE Grade 10 Roll no must be exactly 8 digits",
         422,
         ["g10_board"]
       )}
    end
  end

  defp validate_g10_board(student, _params) do
    if student.g10_roll_no in [nil, ""] or Regex.match?(~r/^[A-Z0-9]{4,10}$/, student.g10_roll_no) do
      :ok
    else
      {:error,
       error(
         "invalid_g10_roll_for_board",
         "Grade 10 Roll no must be 4 to 10 characters",
         422,
         ["g10_board"]
       )}
    end
  end

  defp enrollment_plan(student, params) do
    grade_changed? = Map.has_key?(params, "grade")
    needs_enrollment_change? = grade_changed? or Map.has_key?(params, "stream")

    if needs_enrollment_change? do
      with {:ok, grade} <- fetch_grade(params["grade"] || current_grade_number(student)),
           {:ok, batch} <-
             fetch_batch(
               grade.number,
               normalize_stream(params["stream"] || student.stream),
               params["program_id"]
             ),
           {:ok, student_id} <- maybe_generated_student_id(student, grade.number, grade_changed?) do
        {:ok,
         %{
           grade: grade,
           batch: batch,
           student_attrs: student_attrs_for_plan(grade, student_id, grade_changed?),
           changed_values:
             derived_changed_values(student, grade, batch, student_id, grade_changed?)
         }}
      end
    else
      {:ok, %{student_attrs: %{}, changed_values: %{}}}
    end
  end

  defp fetch_grade(grade_number) do
    case Grades.get_grade_by_number(to_int(grade_number)) do
      nil -> {:error, error("grade_not_found", "Grade not found", 422, ["grade"])}
      grade when grade.number in [11, 12] -> {:ok, grade}
      _grade -> {:error, error("invalid_grade", "Grade must be 11 or 12", 422, ["grade"])}
    end
  end

  defp current_grade_number(%{grade_id: nil}), do: nil

  defp current_grade_number(student) do
    case Grades.get_grade(student.grade_id) do
      nil -> nil
      grade -> grade.number
    end
  end

  defp fetch_batch(grade, stream, program_id) do
    batches =
      from(b in Batch,
        where:
          b.program_id == ^to_int(program_id) and
            fragment("?->>'grade' = ?", b.metadata, ^to_string(grade)) and
            fragment("?->>'stream' = ?", b.metadata, ^stream)
      )
      |> Repo.all()

    case batches do
      [batch] ->
        case Groups.get_group_by_child_id_and_type(batch.id, "batch") do
          nil ->
            {:error, error("batch_group_not_found", "Batch group not found", 422, ["stream"])}

          _group ->
            {:ok, batch}
        end

      [] ->
        {:error, error("batch_not_found", "No matching batch found", 422, ["grade", "stream"])}

      _ ->
        {:error,
         error("multiple_batches", "Multiple matching batches found", 422, ["grade", "stream"])}
    end
  end

  defp generated_student_id(%{g10_roll_no: value}, _grade) when value in [nil, ""], do: {:ok, nil}

  defp generated_student_id(student, grade) do
    student_id = "#{g12_graduating_year(grade)}#{student.g10_roll_no}"

    case Repo.get_by(Student, student_id: student_id) do
      nil ->
        {:ok, student_id}

      %{id: id} when id == student.id ->
        {:ok, student_id}

      _student ->
        {:error,
         error("duplicate_student_id", "Generated Student ID already exists", 409, ["grade"])}
    end
  end

  defp g12_graduating_year(11), do: 2028
  defp g12_graduating_year(12), do: 2027

  defp maybe_generated_student_id(student, grade, true), do: generated_student_id(student, grade)
  defp maybe_generated_student_id(student, _grade, false), do: {:ok, student.student_id}

  defp student_attrs_for_plan(grade, student_id, true) do
    %{
      "grade_id" => grade.id,
      "g12_graduating_year" => g12_graduating_year(grade.number),
      "student_id" => student_id
    }
  end

  defp student_attrs_for_plan(_grade, _student_id, false), do: %{}

  defp derived_changed_values(student, grade, batch, student_id, include_grade_values?) do
    current_grade = current_grade_number(student)
    current_batch = current_enrollment(student.user_id, "batch")

    grade_values =
      if include_grade_values? do
        %{
          "grade" => old_new(current_grade, grade.number),
          "g12_graduating_year" =>
            old_new(student.g12_graduating_year, g12_graduating_year(grade.number)),
          "student_id" => old_new(student.student_id, student_id)
        }
      else
        %{}
      end

    grade_values
    |> Map.put("batch_id", old_new(current_batch && current_batch.group_id, batch.id))
    |> Enum.reject(fn {_field, %{"old" => old, "new" => new}} -> old == new end)
    |> Map.new()
  end

  defp current_enrollment(user_id, group_type) do
    Repo.one(
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true
      )
    )
  end

  defp changed_values(user, student, params, plan) do
    values =
      params
      |> Map.take(@user_fields)
      |> Enum.map(fn {field, new} ->
        old = Map.get(user, String.to_existing_atom(field))
        {field, old_new(audit_value(field, old), audit_value(field, new))}
      end)
      |> Kernel.++(
        params
        |> Map.take(@student_fields)
        |> Enum.map(fn {field, new} ->
          old = Map.get(student, String.to_existing_atom(field))
          {field, old_new(audit_value(field, old), audit_value(field, new))}
        end)
      )
      |> Enum.reject(fn {_field, %{"old" => old, "new" => new}} -> old == new end)
      |> Map.new()
      |> Map.merge(plan.changed_values)

    {:ok, values}
  end

  defp old_new(old, new), do: %{"old" => old, "new" => new}

  defp update_user(user, params) do
    case params |> Map.take(@user_fields) |> empty_to_ok(user, &Users.update_user/2) do
      {:ok, user} ->
        {:ok, user}

      {:error, _changeset} ->
        {:error, error("invalid_user_fields", "User fields are invalid", 422)}
    end
  end

  defp update_student(student, params, plan) do
    attrs =
      params
      |> Map.take(@student_fields)
      |> Map.merge(plan.student_attrs)

    case attrs |> empty_to_ok(student, &Users.update_student/2) do
      {:ok, student} ->
        {:ok, student}

      {:error, _changeset} ->
        {:error, error("invalid_student_fields", "Student fields are invalid", 422)}
    end
  end

  defp empty_to_ok(attrs, schema, update) do
    if attrs == %{}, do: {:ok, schema}, else: update.(schema, attrs)
  end

  defp replace_enrollments(_user_id, plan, _params) when not is_map_key(plan, :batch),
    do: {:ok, :unchanged}

  defp replace_enrollments(user_id, %{grade: grade, batch: batch}, params) do
    with {:ok, _grade} <- replace_enrollment(user_id, "grade", grade.id, params),
         {:ok, _batch} <- replace_enrollment(user_id, "batch", batch.id, params) do
      {:ok, :replaced}
    end
  end

  defp replace_enrollment(user_id, group_type, group_id, params) do
    case current_enrollment(user_id, group_type) do
      %{group_id: ^group_id} ->
        {:ok, :unchanged}

      _old ->
        from(e in EnrollmentRecord,
          where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true,
          update: [set: [is_current: false, end_date: ^params["start_date"]]]
        )
        |> Repo.update_all([])

        with {:ok, enrollment} <-
               %EnrollmentRecord{}
               |> EnrollmentRecord.changeset(%{
                 "user_id" => user_id,
                 "group_id" => group_id,
                 "group_type" => group_type,
                 "academic_year" => params["academic_year"],
                 "start_date" => params["start_date"],
                 "is_current" => true
               })
               |> Repo.insert(),
             {:ok, _group_user} <- replace_group_user(user_id, group_type, group_id) do
          {:ok, enrollment}
        else
          {:error, _reason} ->
            {:error,
             error("enrollment_update_failed", "Enrollment update failed", 422, [group_type])}
        end
    end
  end

  defp replace_group_user(user_id, group_type, child_id) do
    new_group = Groups.get_group_by_child_id_and_type(child_id, group_type)

    old_group_user =
      from(gu in GroupUser,
        join: g in assoc(gu, :group),
        where: gu.user_id == ^user_id and g.type == ^group_type,
        limit: 1
      )
      |> Repo.one()

    cond do
      is_nil(new_group) ->
        {:error, :missing_group}

      old_group_user ->
        GroupUsers.update_group_user(old_group_user, %{group_id: new_group.id})

      true ->
        GroupUsers.create_group_user(%{user_id: user_id, group_id: new_group.id})
    end
  end

  defp insert_audit(user, student, school, params, changed_values) do
    %LmsStudentWriteAudit{}
    |> LmsStudentWriteAudit.changeset(%{
      action: @action,
      actor_user_id: get_in(params, ["actor", "user_id"]),
      actor_email: get_in(params, ["actor", "email"]),
      actor_login_type: get_in(params, ["actor", "login_type"]),
      actor_role: get_in(params, ["actor", "role"]),
      school_code: school.code,
      school_udise_code: school.udise_code,
      program_id: to_int(params["program_id"]),
      row_counts: %{},
      affected_identifiers: %{
        "student_pk_id" => student.id,
        "user_id" => user.id,
        "student_id" => student.student_id,
        "apaar_id" => student.apaar_id,
        "g10_roll_no" => student.g10_roll_no
      },
      created_values: %{},
      changed_values: changed_values
    })
    |> Repo.insert()
  end

  defp error(code, message, status, fields \\ []) do
    %{"code" => code, "message" => message, "status" => status, "fields" => fields}
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_int(_value), do: nil

  defp audit_value("last_name", ""), do: nil
  defp audit_value("stream", value), do: normalize_stream(value)
  defp audit_value(_field, value), do: value

  defp normalize_stream(value) when is_binary(value) do
    trimmed = String.trim(value)

    Enum.find(Dbservice.Utils.Util.valid_streams(), trimmed, fn valid ->
      String.downcase(valid) == String.downcase(trimmed)
    end)
  end

  defp normalize_stream(value), do: value
end
