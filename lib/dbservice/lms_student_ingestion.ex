defmodule Dbservice.LmsStudentIngestion do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias Dbservice.Batches.Batch
  alias Dbservice.DataImport.StudentEnrollment
  alias Dbservice.Grades
  alias Dbservice.Groups
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Users.Student
  alias Dbservice.Users.User
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  @action "student_bulk_create"
  @auth_group "EnableStudents"
  @cbse_board "CENTRAL BOARD OF SECONDARY EDUCATION"
  @empty_totals %{
    "created" => 0,
    "duplicate_in_file" => 0,
    "already_exists" => 0,
    "rejected" => 0
  }

  def bulk_create(%{"rows" => rows} = params) when is_list(rows) do
    school = get_school(params)
    program_id = params["program_id"]

    classified =
      rows
      |> Enum.map(&normalize_row/1)
      |> classify_rows(school, program_id)

    results_with_audits =
      Enum.map(classified, fn
        {:create, row} -> create_row(params, school, row)
        {:skip, result} -> {result, nil}
      end)

    results = Enum.map(results_with_audits, &elem(&1, 0))
    final_totals = totals(results)
    audit_ids = results_with_audits |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)
    update_audit_counts(audit_ids, final_totals)

    {:ok,
     %{
       "upload_id" => get_in(params, ["upload", "id"]),
       "totals" => final_totals,
       "results" => results
     }}
  end

  def bulk_create(_params), do: {:error, :bad_request, %{"error" => "rows must be a list"}}

  defp classify_rows(rows, school, program_id) do
    rows
    |> Enum.map_reduce(MapSet.new(), fn row, seen ->
      identifiers = identifier_keys(row)

      cond do
        identifiers == [] ->
          {{:skip, rejected(row, ["APAAR ID or Grade 10 Roll no is required"])}, seen}

        Enum.any?(identifiers, &MapSet.member?(seen, &1)) ->
          {{:skip, result(row, "duplicate_in_file")}, seen}

        true ->
          seen = Enum.reduce(identifiers, seen, &MapSet.put(&2, &1))
          {classify_row(row, school, program_id), seen}
      end
    end)
    |> elem(0)
  end

  defp classify_row(row, nil, _program_id), do: {:skip, rejected(row, ["School not found"])}

  defp classify_row(row, school, program_id) do
    with :ok <- validate_school(row, school, program_id),
         :ok <- validate_grade(row),
         :ok <- validate_batch(row, program_id),
         :ok <- validate_g10_roll(row),
         :ok <- validate_identifier_match(row) do
      {:create, row}
    else
      {:already_exists, existing} -> {:skip, already_exists(row, existing)}
      {:error, message} -> {:skip, rejected(row, [message])}
    end
  end

  defp create_row(params, school, row) do
    with {:ok, grade} <- fetch_grade(row),
         {:ok, batch} <- fetch_batch(row, params["program_id"]) do
      enrollment_params = %{
        "auth_group" => @auth_group,
        "school_code" => school.code,
        "batch_id" => batch.batch_id,
        "grade_id" => grade.id,
        "academic_year" => params["academic_year"],
        "start_date" => params["start_date"]
      }

      student_attrs =
        row["student"]
        |> Map.put("grade_id", grade.id)

      Multi.new()
      |> Multi.insert(:user, User.changeset(%User{}, row["user"]))
      |> Multi.insert(:student, fn %{user: user} ->
        Student.changeset(%Student{}, Map.put(student_attrs, "user_id", user.id))
      end)
      |> Multi.run(:enrollments, fn _repo, %{user: user} ->
        StudentEnrollment.create_enrollments(user, enrollment_params)
      end)
      |> Multi.insert(:audit, fn %{user: user, student: student} ->
        LmsStudentWriteAudit.changeset(%LmsStudentWriteAudit{}, %{
          action: @action,
          actor_user_id: get_in(params, ["actor", "user_id"]),
          actor_email: get_in(params, ["actor", "email"]),
          actor_login_type: get_in(params, ["actor", "login_type"]),
          actor_role: get_in(params, ["actor", "role"]),
          school_code: school.code,
          school_udise_code: school.udise_code,
          program_id: params["program_id"],
          upload_id: get_in(params, ["upload", "id"]),
          upload_filename: get_in(params, ["upload", "filename"]),
          row_number: row["row_number"],
          row_counts: @empty_totals,
          affected_identifiers: identifiers(row),
          created_values:
            identifiers(row)
            |> Map.put("student_pk_id", student.id)
            |> Map.put("user_id", user.id)
            |> Map.put("batch_id", batch.batch_id)
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{student: student, audit: audit}} ->
          result =
            row
            |> result("created")
            |> Map.put("student_pk_id", student.id)

          {result, audit.id}

        {:error, :student, _changeset, _changes} ->
          result =
            case existing_student(row) do
              nil -> rejected(row, ["Student could not be created"])
              existing -> already_exists(row, existing)
            end

          {result, nil}

        {:error, _step, reason, _changes} ->
          {rejected(row, [format_error(reason)]), nil}
      end
    else
      {:error, message} -> {rejected(row, [message]), nil}
    end
  end

  defp normalize_row(row) do
    grade = to_int(row["grade"])
    g10_roll_no = normalize_roll(row["g10_roll_no"])
    student_id = generated_student_id(grade, g10_roll_no)
    student_name = normalize_name(row["student_name"])

    row
    |> Map.put("row_number", row["row_number"])
    |> Map.put("normalized", %{
      "student_name" => student_name,
      "g10_roll_no" => g10_roll_no,
      "student_id" => student_id
    })
    |> Map.put("generated_student_id", student_id)
    |> Map.put("user", %{
      "first_name" => student_name,
      "date_of_birth" => row["date_of_birth"],
      "gender" => row["gender"],
      "phone" => row["phone"],
      "role" => "student"
    })
    |> Map.put("student", %{
      "student_id" => student_id,
      "apaar_id" => trim_blank_to_nil(row["apaar_id"]),
      "category" => row["category"],
      "physically_handicapped" => row["physically_handicapped"],
      "g10_board" => row["g10_board"],
      "g10_roll_no" => blank_to_nil(g10_roll_no),
      "board_stream" => row["board_stream"],
      "stream" => normalize_stream(row["stream"]),
      "father_name" => normalize_name(row["father_name"]),
      "annual_family_income" => row["annual_family_income"],
      "g12_graduating_year" => g12_graduating_year(grade),
      "status" => "enrolled"
    })
  end

  defp normalize_roll(value) when is_binary(value) do
    value
    |> String.replace(~r/\s+/, "")
    |> String.upcase()
  end

  defp normalize_roll(_value), do: nil

  defp normalize_name(value) when is_binary(value) do
    value
    |> String.replace(".", "")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp normalize_name(_value), do: nil

  defp generated_student_id(_grade, value) when value in [nil, ""], do: nil
  defp generated_student_id(11, roll), do: "2028" <> roll
  defp generated_student_id(12, roll), do: "2027" <> roll
  defp generated_student_id(_grade, roll), do: roll

  defp g12_graduating_year(11), do: 2028
  defp g12_graduating_year(12), do: 2027
  defp g12_graduating_year(_grade), do: nil

  defp validate_school(_row, school, program_id) do
    program_id = to_int(program_id)

    if school_program_allowed?(school, program_id) do
      :ok
    else
      {:error, "School is not eligible for this program"}
    end
  end

  defp school_program_allowed?(_school, nil), do: false

  defp school_program_allowed?(school, program_id) do
    program_id in (school.program_ids || []) ||
      school_has_active_centre_program?(school.id, program_id) ||
      school_has_current_student_program?(school.id, program_id)
  end

  defp school_has_active_centre_program?(school_id, program_id) do
    from(c in "centres",
      where:
        field(c, :school_id) == ^school_id and
          field(c, :program_id) == ^program_id and
          field(c, :is_active) == true
    )
    |> Repo.exists?()
  end

  defp school_has_current_student_program?(school_id, program_id) do
    from(gu in GroupUser,
      join: g in Group,
      on: g.id == gu.group_id and g.type == "school" and g.child_id == ^school_id,
      join: er in EnrollmentRecord,
      on: er.user_id == gu.user_id and er.group_type == "batch" and er.is_current == true,
      join: b in Batch,
      on: b.id == er.group_id,
      where: b.program_id == ^program_id
    )
    |> Repo.exists?()
  end

  defp validate_grade(row) do
    case to_int(row["grade"]) do
      grade when grade in [11, 12] -> :ok
      _ -> {:error, "Grade must be 11 or 12"}
    end
  end

  defp validate_batch(row, program_id) do
    case fetch_batch(row, program_id) do
      {:ok, _batch} -> :ok
      error -> error
    end
  end

  defp validate_g10_roll(row) do
    g10_roll_no = get_in(row, ["student", "g10_roll_no"])
    g10_board = row["g10_board"]

    cond do
      g10_roll_no in [nil, ""] ->
        :ok

      g10_board == @cbse_board and Regex.match?(~r/^\d{8}$/, g10_roll_no) ->
        :ok

      g10_board == @cbse_board ->
        {:error, "CBSE Grade 10 Roll no must be exactly 8 digits"}

      Regex.match?(~r/^[A-Z0-9]{4,10}$/, g10_roll_no) ->
        :ok

      true ->
        {:error, "Grade 10 Roll no must be 4 to 10 characters"}
    end
  end

  defp validate_identifier_match(row) do
    student_by_id = find_student("student_id", get_in(row, ["student", "student_id"]))
    student_by_apaar = find_student("apaar_id", get_in(row, ["student", "apaar_id"]))

    cond do
      student_by_id && student_by_apaar && student_by_id.id != student_by_apaar.id ->
        {:error, "APAAR ID and generated Student ID match different existing students"}

      student_by_id ->
        {:already_exists, student_by_id}

      student_by_apaar ->
        {:already_exists, student_by_apaar}

      true ->
        :ok
    end
  end

  defp fetch_grade(row) do
    case Grades.get_grade_by_number(to_int(row["grade"])) do
      nil -> {:error, "Grade not found"}
      grade -> {:ok, grade}
    end
  end

  defp fetch_batch(row, program_id) do
    grade = to_int(row["grade"])
    stream = get_in(row, ["student", "stream"]) || normalize_stream(row["stream"])

    batches =
      from(b in Batch,
        where:
          b.program_id == ^program_id and
            fragment("?->>'grade' = ?", b.metadata, ^to_string(grade)) and
            fragment("?->>'stream' = ?", b.metadata, ^stream)
      )
      |> Repo.all()

    case batches do
      [batch] ->
        case Groups.get_group_by_child_id_and_type(batch.id, "batch") do
          nil -> {:error, "Batch group not found"}
          _group -> {:ok, batch}
        end

      [] ->
        {:error, "No matching batch found"}

      _ ->
        {:error, "Multiple matching batches found"}
    end
  end

  defp get_school(%{"school" => %{"code" => code, "udise_code" => udise_code}}) do
    case Schools.get_school_by_code(code) do
      %{udise_code: ^udise_code} = school -> school
      _ -> nil
    end
  end

  defp get_school(_params), do: nil

  defp find_student(_field, value) when value in [nil, ""], do: nil
  defp find_student("student_id", value), do: Repo.get_by(Student, student_id: value)
  defp find_student("apaar_id", value), do: Repo.get_by(Student, apaar_id: value)

  defp existing_student(row) do
    find_student("student_id", get_in(row, ["student", "student_id"])) ||
      find_student("apaar_id", get_in(row, ["student", "apaar_id"]))
  end

  defp identifier_keys(row) do
    identifiers(row)
    |> Enum.map(fn {key, value} -> "#{key}:#{value}" end)
  end

  defp identifiers(row) do
    %{
      "student_id" => get_in(row, ["student", "student_id"]),
      "apaar_id" => get_in(row, ["student", "apaar_id"]),
      "g10_roll_no" => get_in(row, ["student", "g10_roll_no"])
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp already_exists(row, existing) do
    row
    |> result("already_exists")
    |> Map.put("existing_match", %{
      "student_pk_id" => existing.id,
      "student_id" => existing.student_id,
      "apaar_id" => existing.apaar_id
    })
  end

  defp rejected(row, errors), do: row |> result("rejected") |> Map.put("row_errors", errors)

  defp result(row, status) do
    %{
      "row_number" => row["row_number"],
      "status" => status,
      "generated_student_id" => row["generated_student_id"],
      "normalized" => row["normalized"],
      "field_errors" => %{},
      "row_errors" => [],
      "existing_match" => nil
    }
  end

  defp totals(results) do
    status_counts =
      Enum.reduce(results, @empty_totals, fn result, acc ->
        Map.update!(acc, result["status"], &(&1 + 1))
      end)

    Map.put(status_counts, "total", length(results))
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_int(_value), do: nil

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp trim_blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim_blank_to_nil(_value), do: nil

  defp normalize_stream(value) when is_binary(value) do
    trimmed = String.trim(value)

    Enum.find(Dbservice.Utils.Util.valid_streams(), trimmed, fn valid ->
      String.downcase(valid) == String.downcase(trimmed)
    end)
  end

  defp normalize_stream(value), do: value

  defp update_audit_counts([], _row_counts), do: :ok

  defp update_audit_counts(audit_ids, row_counts) do
    from(a in LmsStudentWriteAudit, where: a.id in ^audit_ids)
    |> Repo.update_all(set: [row_counts: row_counts])

    :ok
  end

  defp format_error(%Ecto.Changeset{}), do: "Validation failed"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
