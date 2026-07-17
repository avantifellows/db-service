defmodule Dbservice.LmsStudentIngestion do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias Dbservice.Batches.Batch
  alias Dbservice.DataImport.StudentEnrollment
  alias Dbservice.Grades
  alias Dbservice.Groups
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Programs.Program
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Users.Student
  alias Dbservice.Users.User

  @action "student_bulk_create"
  @auth_group "EnableStudents"
  @cbse_board "CBSE"
  @nvs_program_id 64
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
      |> Enum.map(&normalize_row(&1, params["academic_year"]))
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
          {{:skip, rejected(row, ["PEN Number or Grade 10 Roll no is required"])}, seen}

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
         :ok <- validate_academic_year(row),
         :ok <- validate_batch(row, program_id),
         :ok <- validate_pen(row),
         :ok <- validate_g10_board(row),
         :ok <- validate_g10_roll(row),
         :ok <- validate_profile(row),
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
      |> Multi.insert(:user, user_changeset(row["user"]))
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
          affected_identifiers: audit_identifiers(row, user, student),
          created_values:
            row["user"]
            |> Map.merge(row["student"])
            |> Map.merge(audit_identifiers(row, user, student))
            |> Map.merge(%{
              "school_id" => school.id,
              "grade_id" => grade.id,
              "batch_id" => batch.batch_id,
              "batch_pk_id" => batch.id
            })
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user, student: student, audit: audit}} ->
          result =
            row
            |> result("created")
            |> Map.merge(%{
              "student_pk_id" => student.id,
              "user_id" => user.id,
              "student_id" => student.student_id,
              "pen_number" => student.pen_number,
              "apaar_id" => student.apaar_id,
              "batch_id" => batch.batch_id,
              "batch_pk_id" => batch.id,
              "audit_id" => audit.id
            })

          {result, audit.id}

        {:error, :student, _changeset, _changes} ->
          result =
            case existing_student(row) do
              nil -> rejected(row, ["Student could not be created"])
              existing -> already_exists(row, existing)
            end

          {result, nil}

        {:error, _step, _reason, _changes} ->
          {rejected(row, ["Student could not be created"]), nil}
      end
    else
      {:error, message} -> {rejected(row, [message]), nil}
    end
  end

  defp normalize_row(row, academic_year) do
    grade = to_int(row["grade"])
    pen_number = trim_blank_to_nil(row["pen_number"])
    g10_board = normalize_g10_board(row["g10_board"])
    g10_roll_no = normalize_g10_roll(row["g10_roll_no"], g10_board)
    graduating_year = g12_graduating_year(grade, academic_year)
    student_id = generated_student_id(graduating_year, g10_roll_no)
    student_name = normalize_name(row["student_name"])
    gender = normalize_gender(row["gender"])
    date_of_birth = normalize_date_of_birth(row["date_of_birth"])

    row
    |> Map.put("row_number", row["row_number"])
    |> Map.put("normalized", %{
      "student_name" => student_name,
      "pen_number" => pen_number,
      "g10_roll_no" => g10_roll_no,
      "student_id" => student_id,
      "g10_board" => g10_board,
      "gender" => gender,
      "date_of_birth" => date_of_birth,
      "category" => row["category"],
      "physically_handicapped" => row["physically_handicapped"],
      "stream" => normalize_stream(row["stream"]),
      "g12_graduating_year" => graduating_year
    })
    |> Map.put("generated_student_id", student_id)
    |> Map.put("user", %{
      "first_name" => student_name,
      "date_of_birth" => date_of_birth,
      "gender" => gender,
      "phone" => row["phone"],
      "role" => "student"
    })
    |> Map.put("student", %{
      "student_id" => student_id,
      "pen_number" => pen_number,
      "category" => row["category"],
      "physically_handicapped" => row["physically_handicapped"],
      "g10_board" => g10_board,
      "g10_roll_no" => blank_to_nil(g10_roll_no),
      "board_stream" => row["board_stream"],
      "stream" => normalize_stream(row["stream"]),
      "father_name" => normalize_name(row["father_name"]),
      "annual_family_income" => row["annual_family_income"],
      "g12_graduating_year" => graduating_year,
      "status" => "enrolled"
    })
  end

  defp user_changeset(attrs), do: User.changeset(%User{}, attrs)

  def normalize_g10_roll(value, @cbse_board) when is_binary(value), do: String.trim(value)

  def normalize_g10_roll(value, nil) when is_binary(value) do
    value
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> String.upcase()
    |> String.trim_leading("0")
  end

  def normalize_g10_roll(value, _board) when is_binary(value) do
    value |> String.replace(~r/\s+/, "") |> String.upcase()
  end

  def normalize_g10_roll(_value, _board), do: nil

  def normalize_g10_board(value) when is_binary(value) do
    case String.trim(value) do
      "CBSE" -> @cbse_board
      "Others" -> nil
      "" -> nil
      board -> board
    end
  end

  def normalize_g10_board(value), do: value

  defp normalize_name(value) when is_binary(value) do
    value
    |> String.replace(".", "")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp normalize_name(_value), do: nil

  defp generated_student_id(_graduating_year, value) when value in [nil, ""], do: nil
  defp generated_student_id(year, roll) when is_integer(year), do: "#{year}#{roll}"
  defp generated_student_id(_graduating_year, roll), do: roll

  defp g12_graduating_year(grade, academic_year) when grade in [11, 12] do
    case Regex.run(~r/^(\d{4})-(\d{4})$/, to_string(academic_year)) do
      [_, start_year, end_year] ->
        start_year = String.to_integer(start_year)
        end_year = String.to_integer(end_year)
        if end_year == start_year + 1, do: end_year + (12 - grade), else: nil

      _ ->
        nil
    end
  end

  defp g12_graduating_year(_grade, _academic_year), do: nil

  defp validate_school(_row, _school, program_id) do
    if current_nvs_program?(to_int(program_id)) do
      :ok
    else
      {:error, "Program must be a current NVS program"}
    end
  end

  def current_nvs_program?(nil), do: false

  def current_nvs_program?(program_id) do
    from(p in Program,
      where: p.id == ^program_id and p.id == @nvs_program_id and p.is_current == true
    )
    |> Repo.exists?()
  end

  defp validate_grade(row) do
    case to_int(row["grade"]) do
      grade when grade in [11, 12] -> :ok
      _ -> {:error, "Grade must be 11 or 12"}
    end
  end

  defp validate_academic_year(row) do
    if is_integer(get_in(row, ["student", "g12_graduating_year"])),
      do: :ok,
      else: {:error, "Academic year must be YYYY-YYYY"}
  end

  defp validate_batch(row, program_id) do
    case fetch_batch(row, program_id) do
      {:ok, _batch} -> :ok
      error -> error
    end
  end

  defp validate_g10_roll(row) do
    g10_roll_no = get_in(row, ["student", "g10_roll_no"])
    supplied_roll = row["g10_roll_no"]

    if supplied_roll in [nil, ""] or
         (is_binary(supplied_roll) and String.trim(supplied_roll) == "") do
      :ok
    else
      validate_nonblank_g10_roll(g10_roll_no, get_in(row, ["student", "g10_board"]))
    end
  end

  defp validate_nonblank_g10_roll(g10_roll_no, g10_board) do
    cond do
      g10_board == @cbse_board and is_binary(g10_roll_no) and
          Regex.match?(~r/^[1-9]\d{7}$/, g10_roll_no) ->
        :ok

      g10_board == @cbse_board ->
        {:error, "CBSE Grade 10 Roll no must be exactly 8 digits and cannot start with zero"}

      is_binary(g10_roll_no) and Regex.match?(~r/^[A-Z0-9]{4,10}$/, g10_roll_no) ->
        :ok

      true ->
        {:error, "Grade 10 Roll no must be 4 to 10 characters"}
    end
  end

  defp validate_g10_board(row) do
    board =
      if is_binary(row["g10_board"]), do: String.trim(row["g10_board"]), else: row["g10_board"]

    roll = get_in(row, ["student", "g10_roll_no"])

    if board in ["CBSE", "Others"] or (roll in [nil, ""] and board in [nil, ""]),
      do: :ok,
      else: {:error, "Grade 10 Board must be CBSE or Others"}
  end

  defp validate_pen(row) do
    case {row["pen_number"], get_in(row, ["student", "pen_number"])} do
      {value, _normalized} when not is_nil(value) and not is_binary(value) ->
        {:error, "PEN Number must be exactly 11 digits and cannot start with zero"}

      {_input, nil} ->
        :ok

      {_input, pen} when is_binary(pen) ->
        if Regex.match?(~r/^[1-9][0-9]{10}$/, pen),
          do: :ok,
          else: {:error, "PEN Number must be exactly 11 digits and cannot start with zero"}

      _ ->
        {:error, "PEN Number must be exactly 11 digits and cannot start with zero"}
    end
  end

  defp validate_profile(row) do
    with :ok <- validate_category_pair(row),
         :ok <- validate_gender(row),
         :ok <- validate_phone(row) do
      validate_date_of_birth(row)
    end
  end

  defp validate_phone(row) do
    if Regex.match?(~r/^[1-9]\d{9}$/, get_in(row, ["user", "phone"]) || ""),
      do: :ok,
      else: {:error, "Parents Phone Number must be exactly 10 digits and cannot start with zero"}
  end

  defp validate_category_pair(row) do
    category = get_in(row, ["student", "category"])
    cwsn = get_in(row, ["student", "physically_handicapped"])

    cond do
      cwsn == false and category not in ~w(Gen Gen-EWS OBC SC ST) ->
        {:error, "Category does not match CWSN status"}

      cwsn == true and category not in ~w(PWD-Gen PWD-EWS PWD-OBC PWD-SC PWD-ST) ->
        {:error, "Category does not match CWSN status"}

      cwsn not in [true, false] ->
        {:error, "CWSN status must be true or false"}

      true ->
        :ok
    end
  end

  defp validate_gender(row) do
    if get_in(row, ["user", "gender"]) in ~w(Male Female Other),
      do: :ok,
      else: {:error, "Gender must be Male, Female, or Other"}
  end

  defp validate_date_of_birth(row) do
    case get_in(row, ["user", "date_of_birth"]) do
      %Date{} = date ->
        if Date.compare(date, ~D[2000-01-01]) != :lt and
             Date.compare(date, ~D[2015-12-31]) != :gt,
           do: :ok,
           else: {:error, "Date of Birth must be a valid date between 2000-01-01 and 2015-12-31"}

      _ ->
        {:error, "Date of Birth must be a valid date between 2000-01-01 and 2015-12-31"}
    end
  end

  defp validate_identifier_match(row) do
    student_id = get_in(row, ["student", "student_id"])
    pen_number = get_in(row, ["student", "pen_number"])
    student_by_id = find_student("student_id", student_id)
    student_by_pen = find_student("pen_number", pen_number)
    existing = student_by_id || student_by_pen

    case {identifier_conflict(student_by_id, student_by_pen, student_id, pen_number), existing} do
      {nil, nil} -> :ok
      {nil, student} -> {:already_exists, student}
      {error, _student} -> {:error, error}
    end
  end

  defp identifier_conflict(student_by_id, student_by_pen, student_id, pen_number) do
    cond do
      student_by_id && student_by_pen && student_by_id.id != student_by_pen.id ->
        "PEN Number and generated Student ID match different existing students"

      student_by_id && conflicting_identifier?(student_by_id.pen_number, pen_number) ->
        "PEN Number conflicts with the existing generated Student ID"

      student_by_pen && conflicting_identifier?(student_by_pen.student_id, student_id) ->
        "Generated Student ID conflicts with the existing PEN Number"

      true ->
        nil
    end
  end

  defp conflicting_identifier?(stored, supplied) do
    stored not in [nil, ""] and supplied not in [nil, ""] and stored != supplied
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
    batches = matching_batches(grade, stream, program_id)

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

  def matching_batches(grade, stream, program_id) do
    from(b in Batch,
      where:
        b.program_id == ^program_id and
          fragment("?->>'grade' = ?", b.metadata, ^to_string(grade)) and
          fragment("?->>'stream' = ?", b.metadata, ^stream)
    )
    |> Repo.all()
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
  defp find_student("pen_number", value), do: Repo.get_by(Student, pen_number: value)

  defp existing_student(row) do
    find_student("student_id", get_in(row, ["student", "student_id"])) ||
      find_student("pen_number", get_in(row, ["student", "pen_number"]))
  end

  defp identifier_keys(row) do
    identifiers(row)
    |> Enum.map(fn {key, value} -> "#{key}:#{value}" end)
  end

  defp identifiers(row) do
    %{
      "student_id" => get_in(row, ["student", "student_id"]),
      "pen_number" => get_in(row, ["student", "pen_number"]),
      "g10_roll_no" => get_in(row, ["student", "g10_roll_no"])
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp audit_identifiers(row, user, student) do
    %{
      "student_pk_id" => student.id,
      "user_id" => user.id,
      "student_id" => student.student_id,
      "pen_number" => student.pen_number,
      "apaar_id" => student.apaar_id,
      "g10_roll_no" => get_in(row, ["student", "g10_roll_no"])
    }
  end

  defp already_exists(row, existing) do
    row
    |> result("already_exists")
    |> Map.put("existing_match", %{
      "student_pk_id" => existing.id,
      "user_id" => existing.user_id,
      "student_id" => existing.student_id,
      "pen_number" => existing.pen_number,
      "apaar_id" => existing.apaar_id,
      "g10_roll_no" => existing.g10_roll_no
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

  defp normalize_gender("Others"), do: "Other"
  defp normalize_gender(value), do: value

  @doc false
  def normalize_date_of_birth(value) when is_binary(value) do
    with {:error, _} <- Date.from_iso8601(value),
         [day, month, year] <- String.split(value, ~r{[/-]}),
         {day, ""} <- Integer.parse(day),
         {month, ""} <- Integer.parse(month),
         {year, ""} <- Integer.parse(year),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      {:ok, date} -> date
      _ -> nil
    end
  end

  def normalize_date_of_birth(_value), do: nil

  @doc false
  def normalize_stream(value) when is_binary(value) do
    trimmed = String.trim(value)

    Enum.find(Dbservice.Utils.Util.valid_streams(), trimmed, fn valid ->
      String.downcase(valid) == String.downcase(trimmed)
    end)
  end

  def normalize_stream(value), do: value

  defp update_audit_counts([], _row_counts), do: :ok

  defp update_audit_counts(audit_ids, row_counts) do
    from(a in LmsStudentWriteAudit, where: a.id in ^audit_ids)
    |> Repo.update_all(set: [row_counts: row_counts])

    :ok
  end
end
