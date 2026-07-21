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
  alias Dbservice.LmsStudentIngestion
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Users
  alias Dbservice.Users.Student
  alias Dbservice.Users.User

  @action "student_update"
  @cbse_board "CBSE"
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
    "pen_number",
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
           params = trim_g10_board(params),
           :ok <- validate_canonical_inputs(params),
           params = normalize_params(params),
           {:ok, student} <- fetch_student(student_pk_id),
           {:ok, school} <- fetch_school(params),
           :ok <- validate_school_scope(student, school, params["program_id"]),
           {:ok, user} <- fetch_user(student),
           :ok <- validate_profile_fields(student, params),
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

  defp validate_canonical_inputs(params) do
    with :ok <- validate_board_input(params),
         :ok <- validate_gender_input(params),
         do: validate_stream_input(params)
  end

  defp validate_board_input(params) when not is_map_key(params, "g10_board"), do: :ok

  defp validate_board_input(%{"g10_board" => board}) when board in ~w(CBSE Others), do: :ok

  defp validate_board_input(_params),
    do:
      {:error,
       error("invalid_g10_board", "Grade 10 Board must be CBSE or Others", 422, ["g10_board"])}

  defp trim_g10_board(%{"g10_board" => board} = params) when is_binary(board),
    do: Map.put(params, "g10_board", String.trim(board))

  defp trim_g10_board(params), do: params

  defp validate_gender_input(params) when not is_map_key(params, "gender"), do: :ok

  defp validate_gender_input(%{"gender" => nil}),
    do:
      {:error, error("invalid_gender", "Gender must be Male, Female, or Other", 422, ["gender"])}

  defp validate_gender_input(_params), do: :ok

  defp validate_stream_input(params) when not is_map_key(params, "stream"), do: :ok

  defp validate_stream_input(%{"stream" => stream}) do
    if LmsStudentIngestion.normalize_stream(stream) in Dbservice.Utils.Util.valid_streams(),
      do: :ok,
      else: {:error, error("invalid_stream", "Stream is invalid", 422, ["stream"])}
  end

  defp fetch_student(id) do
    case from(s in Student, where: s.id == ^id, lock: "FOR UPDATE") |> Repo.one() do
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
    program_id = to_int(program_id)
    current_program_batches = current_program_batch_count(student.user_id, program_id)

    cond do
      is_nil(program_id) ->
        {:error, error("program_required", "Program is required", 400)}

      not enrolled?(student.user_id, school.id, "school") ->
        {:error, error("school_mismatch", "Student is not enrolled in this school", 403)}

      # Program-agnostic, data-integrity only: the student must be currently
      # enrolled in exactly one batch of the supplied program. Which programs a
      # given actor may edit is business policy that lives in the LMS API layer,
      # not in this service.
      current_program_batches == 0 ->
        {:error, error("program_mismatch", "Student is not enrolled in this program", 403)}

      current_program_batches > 1 ->
        {:error,
         error("multiple_current_batches", "Multiple current batches found", 409, ["stream"])}

      true ->
        :ok
    end
  end

  defp current_program_batch_count(_user_id, nil), do: 0

  defp current_program_batch_count(user_id, program_id) do
    from(e in EnrollmentRecord,
      join: b in Batch,
      on: b.id == e.group_id,
      where:
        e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
          b.program_id == ^program_id
    )
    |> Repo.aggregate(:count)
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

  defp validate_profile_fields(student, params) do
    with :ok <- validate_category_pair(student, params),
         :ok <- validate_phone(params),
         do: validate_date_of_birth(params)
  end

  defp validate_category_pair(_student, params)
       when not is_map_key(params, "category") and
              not is_map_key(params, "physically_handicapped"),
       do: :ok

  defp validate_category_pair(student, params) do
    category = Map.get(params, "category", student.category)
    cwsn = Map.get(params, "physically_handicapped", student.physically_handicapped)

    valid? =
      (cwsn == false and category in ~w(Gen Gen-EWS OBC SC ST)) or
        (cwsn == true and category in ~w(PWD-Gen PWD-EWS PWD-OBC PWD-SC PWD-ST))

    if valid?,
      do: :ok,
      else:
        {:error,
         error("invalid_category_pair", "Category does not match CWSN status", 422, [
           "category",
           "physically_handicapped"
         ])}
  end

  defp validate_phone(params) when not is_map_key(params, "phone"), do: :ok

  defp validate_phone(%{"phone" => phone}) when is_binary(phone) do
    if Regex.match?(~r/^[1-9]\d{9}$/, phone),
      do: :ok,
      else:
        {:error,
         error(
           "invalid_phone",
           "Parents Phone Number must be exactly 10 digits and cannot start with zero",
           422,
           ["phone"]
         )}
  end

  defp validate_phone(_params),
    do:
      {:error,
       error(
         "invalid_phone",
         "Parents Phone Number must be exactly 10 digits and cannot start with zero",
         422,
         ["phone"]
       )}

  defp validate_date_of_birth(params) when not is_map_key(params, "date_of_birth"), do: :ok

  defp validate_date_of_birth(%{"date_of_birth" => %Date{} = date}) do
    if Date.compare(date, ~D[2000-01-01]) != :lt and
         Date.compare(date, ~D[2015-12-31]) != :gt do
      :ok
    else
      invalid_date_of_birth()
    end
  end

  defp validate_date_of_birth(_params), do: invalid_date_of_birth()

  defp invalid_date_of_birth,
    do:
      {:error,
       error("invalid_date_of_birth", "Date of Birth must be between 2000 and 2015", 422, [
         "date_of_birth"
       ])}

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

  defp validate_g10_board(student, %{"g10_board" => nil}) do
    canonical_roll = LmsStudentIngestion.normalize_g10_roll(student.g10_roll_no, nil)

    if student.g10_roll_no in [nil, ""] or
         (Regex.match?(~r/^[A-Z0-9]{4,10}$/, student.g10_roll_no) and
            canonical_roll == student.g10_roll_no) do
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

  defp validate_g10_board(_student, _params),
    do:
      {:error,
       error("invalid_g10_board", "Grade 10 Board must be CBSE or Others", 422, [
         "g10_board"
       ])}

  defp enrollment_plan(student, params) do
    current_grade = current_grade_number(student)

    submitted_grade =
      if Map.has_key?(params, "grade"), do: to_int(params["grade"]), else: current_grade

    submitted_stream = LmsStudentIngestion.normalize_stream(params["stream"] || student.stream)
    grade_changed? = Map.has_key?(params, "grade") and submitted_grade != current_grade

    stream_changed? =
      Map.has_key?(params, "stream") and
        submitted_stream != LmsStudentIngestion.normalize_stream(student.stream)

    needs_enrollment_change? = grade_changed? or stream_changed?

    if needs_enrollment_change? do
      with {:ok, grade} <- fetch_grade(submitted_grade),
           {:ok, batch} <-
             fetch_batch(grade.number, submitted_stream, params["program_id"]),
           {:ok, current_batch} <- current_program_batch(student.user_id, params["program_id"]),
           {:ok, graduating_year} <- maybe_graduating_year(grade.number, params, grade_changed?),
           {:ok, student_id} <-
             maybe_generated_student_id(student, graduating_year, grade_changed?) do
        {:ok,
         %{
           grade: grade,
           batch: batch,
           current_batch: current_batch,
           grade_changed?: grade_changed?,
           student_attrs:
             student_attrs_for_plan(grade, graduating_year, student_id, grade_changed?),
           changed_values:
             derived_changed_values(
               student,
               grade,
               current_batch,
               batch,
               graduating_year,
               student_id,
               grade_changed?
             )
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
    batches = LmsStudentIngestion.matching_batches(grade, stream, to_int(program_id))

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

  defp current_program_batch(user_id, program_id) do
    program_id = to_int(program_id)

    batches =
      from(e in EnrollmentRecord,
        join: b in Batch,
        on: b.id == e.group_id,
        where:
          e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
            b.program_id == ^program_id,
        select: %{enrollment: e, batch: b}
      )
      |> Repo.all()

    case batches do
      [current] ->
        {:ok, current}

      [] ->
        {:error, error("current_batch_not_found", "Current NVS batch not found", 422, ["stream"])}

      _ ->
        {:error,
         error("multiple_current_batches", "Multiple current NVS batches found", 409, ["stream"])}
    end
  end

  defp generated_student_id(%{g10_roll_no: value}, _graduating_year)
       when value in [nil, ""],
       do: {:ok, nil}

  defp generated_student_id(student, graduating_year) do
    student_id = "#{graduating_year}#{student.g10_roll_no}"

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

  defp maybe_graduating_year(_grade, _params, false), do: {:ok, nil}

  defp maybe_graduating_year(grade, %{"academic_year" => academic_year}, true)
       when is_binary(academic_year) do
    case Regex.run(~r/^(\d{4})-(\d{4})$/, academic_year) do
      [_, start_year, end_year] ->
        start_year = String.to_integer(start_year)
        end_year = String.to_integer(end_year)

        if end_year == start_year + 1 do
          {:ok, if(grade == 11, do: start_year + 2, else: start_year + 1)}
        else
          {:error,
           error("invalid_academic_year", "Academic year must be YYYY-YYYY", 422, [
             "academic_year"
           ])}
        end

      _ ->
        {:error,
         error("invalid_academic_year", "Academic year must be YYYY-YYYY", 422, ["academic_year"])}
    end
  end

  defp maybe_graduating_year(_grade, _params, true),
    do:
      {:error,
       error("invalid_academic_year", "Academic year must be YYYY-YYYY", 422, ["academic_year"])}

  defp maybe_generated_student_id(student, graduating_year, true),
    do: generated_student_id(student, graduating_year)

  defp maybe_generated_student_id(student, _graduating_year, false),
    do: {:ok, student.student_id}

  defp student_attrs_for_plan(grade, graduating_year, student_id, true) do
    %{
      "grade_id" => grade.id,
      "g12_graduating_year" => graduating_year,
      "student_id" => student_id
    }
  end

  defp student_attrs_for_plan(_grade, _graduating_year, _student_id, false), do: %{}

  defp derived_changed_values(
         student,
         grade,
         current_batch,
         batch,
         graduating_year,
         student_id,
         include_grade_values?
       ) do
    current_grade = current_grade_number(student)

    grade_values =
      if include_grade_values? do
        %{
          "grade" => old_new(current_grade, grade.number),
          "g12_graduating_year" => old_new(student.g12_graduating_year, graduating_year),
          "student_id" => old_new(student.student_id, student_id)
        }
      else
        %{}
      end

    grade_values
    |> Map.put("batch_id", old_new(current_batch.batch.id, batch.id))
    |> Enum.reject(fn {_field, %{"old" => old, "new" => new}} -> old == new end)
    |> Map.new()
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
    attrs = Map.take(params, @user_fields)

    result =
      if attrs == %{} do
        {:ok, user}
      else
        user |> User.changeset(attrs) |> Repo.update()
      end

    case result do
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

  defp replace_enrollments(
         user_id,
         %{grade: grade, batch: batch, current_batch: current_batch} = plan,
         params
       ) do
    with {:ok, _grade} <- maybe_replace_grade(user_id, grade, params, plan.grade_changed?),
         {:ok, _batch} <- replace_batch_enrollment(user_id, current_batch, batch, params) do
      {:ok, :replaced}
    end
  end

  defp maybe_replace_grade(_user_id, _grade, _params, false), do: {:ok, :unchanged}

  defp maybe_replace_grade(user_id, grade, params, true) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == "grade" and e.is_current == true,
      update: [set: [is_current: false, end_date: ^params["start_date"]]]
    )
    |> Repo.update_all([])

    insert_enrollment(user_id, "grade", grade.id, params)
  end

  defp replace_batch_enrollment(
         _user_id,
         %{batch: %{id: batch_id}},
         %{id: batch_id},
         _params
       ),
       do: {:ok, :unchanged}

  defp replace_batch_enrollment(user_id, current, batch, params) do
    from(e in EnrollmentRecord,
      where: e.id == ^current.enrollment.id,
      update: [set: [is_current: false, end_date: ^params["start_date"]]]
    )
    |> Repo.update_all([])

    insert_enrollment(user_id, "batch", batch.id, params)
  end

  defp insert_enrollment(user_id, group_type, group_id, params) do
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
        {:error, error("enrollment_update_failed", "Enrollment update failed", 422, [group_type])}
    end
  end

  defp replace_group_user(user_id, "batch", child_id) do
    new_group = Groups.get_group_by_child_id_and_type(child_id, "batch")
    new_batch = Repo.get(Batch, child_id)

    if is_nil(new_group) or is_nil(new_batch) do
      {:error, :missing_group}
    else
      old_group_users =
        from(gu in GroupUser,
          join: g in assoc(gu, :group),
          join: b in Batch,
          on: b.id == g.child_id,
          where:
            gu.user_id == ^user_id and g.type == "batch" and
              b.program_id == ^new_batch.program_id
        )
        |> Repo.all()

      replace_existing_group_user(old_group_users, user_id, new_group.id)
    end
  end

  defp replace_group_user(user_id, group_type, child_id) do
    new_group = Groups.get_group_by_child_id_and_type(child_id, group_type)

    if is_nil(new_group) do
      {:error, :missing_group}
    else
      old_group_users =
        from(gu in GroupUser,
          join: g in assoc(gu, :group),
          where: gu.user_id == ^user_id and g.type == ^group_type
        )
        |> Repo.all()

      replace_existing_group_user(old_group_users, user_id, new_group.id)
    end
  end

  defp replace_existing_group_user(old_group_users, user_id, new_group_id) do
    case old_group_users do
      [] -> GroupUsers.create_group_user(%{user_id: user_id, group_id: new_group_id})
      [old_group_user] -> GroupUsers.update_group_user(old_group_user, %{group_id: new_group_id})
      _ -> {:error, :multiple_group_users}
    end
  end

  defp insert_audit(user, student, school, params, changed_values) do
    result =
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
          "pen_number" => student.pen_number,
          "apaar_id" => student.apaar_id,
          "g10_roll_no" => student.g10_roll_no
        },
        created_values: %{},
        changed_values: changed_values
      })
      |> Repo.insert()

    case result do
      {:ok, audit} -> {:ok, audit}
      {:error, _changeset} -> {:error, error("audit_update_failed", "Audit update failed", 422)}
    end
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
  defp audit_value("stream", value), do: LmsStudentIngestion.normalize_stream(value)
  defp audit_value(_field, value), do: value

  defp normalize_params(params) do
    params
    |> then(fn
      %{"gender" => "Others"} = params -> Map.put(params, "gender", "Other")
      params -> params
    end)
    |> then(fn
      %{"g10_board" => "Others"} = params -> Map.put(params, "g10_board", nil)
      params -> params
    end)
    |> then(fn
      %{"date_of_birth" => value} = params ->
        Map.put(
          params,
          "date_of_birth",
          LmsStudentIngestion.normalize_date_of_birth(value)
        )

      params ->
        params
    end)
    |> then(fn
      %{"stream" => value} = params ->
        Map.put(params, "stream", LmsStudentIngestion.normalize_stream(value))

      params ->
        params
    end)
  end
end
