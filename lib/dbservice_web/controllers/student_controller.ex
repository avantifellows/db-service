defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users.User
  alias Dbservice.Groups
  alias Dbservice.EnrollmentRecords
  alias Dbservice.Schools
  alias Dbservice.Grades
  alias Dbservice.Users
  alias Dbservice.Users.Student
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.GroupUsers
  alias DbserviceWeb.EnrollmentRecordJSON
  alias Dbservice.Statuses
  alias Dbservice.Services.BatchEnrollmentService
  alias Dbservice.Services.StudentUpdateService
  alias Dbservice.Services.DropoutService
  alias Dbservice.Services.ReEnrollmentService
  alias Dbservice.Utils.ChangesetFormatter

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Student, as: SwaggerSchemaStudent

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        Map.merge(
          SwaggerSchemaStudent.student(),
          SwaggerSchemaStudent.students()
        ),
        SwaggerSchemaStudent.student_with_user()
      ),
      Map.merge(
        Map.merge(
          SwaggerSchemaStudent.student_id_generation(),
          SwaggerSchemaStudent.student_id_generation_response()
        )
        |> Map.merge(SwaggerSchemaStudent.verify_student_request())
        |> Map.merge(SwaggerSchemaStudent.verification_result())
        |> Map.merge(SwaggerSchemaStudent.verification_params())
        |> Map.merge(SwaggerSchemaStudent.student_with_enrollments()),
        %{}
      )
    )
  end

  swagger_path :index do
    get("/api/student")

    parameters do
      params(:query, :string, "The id of the student", required: false, name: "student_id")
      params(:query, :string, "The stream of the student", required: false, name: "stream")

      params(:query, :string, "The father's name of the student",
        required: false,
        name: "father_name"
      )
    end

    response(200, "OK", Schema.ref(:Students))
  end

  def index(conn, %{"id" => id, "group" => group} = _params) do
    student = Users.get_student_by_id_and_group(id, group)
    students = if student, do: [student], else: []
    render(conn, :index, student: students)
  end

  def index(conn, params) do
    query =
      from(m in Student,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    student = Repo.all(query)
    render(conn, :index, student: student)
  end

  swagger_path :create do
    post("/api/student")

    parameters do
      body(:body, Schema.ref(:StudentWithUser), "Student to create along with user",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentWithUser))
  end

  def create(conn, params) do
    case Users.create_or_update_student(params) do
      {:ok, student} ->
        conn
        |> put_status(:ok)
        |> render(:show, student: student)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  swagger_path :show do
    get("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
    end

    response(200, "OK", Schema.ref(:Student))
  end

  def show(conn, %{"id" => id}) do
    try do
      student = Users.get_student!(String.to_integer(id))
      render(conn, :show, student: student)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(DbserviceWeb.ErrorJSON)
        |> render(:"404")
    end
  end

  swagger_path :update do
    patch("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
      body(:body, Schema.ref(:Student), "Student to update along with user", required: true)
    end

    response(200, "Updated", Schema.ref(:Student))
  end

  def update(conn, params) do
    student = Users.get_student!(params["id"])

    with {:ok, %Student{} = student} <-
           StudentUpdateService.update_student_with_user_data(student, params) do
      conn
      |> put_status(:ok)
      |> render(:show, student: student)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    student = Users.get_student!(id)

    with {:ok, %Student{}} <- Users.delete_student(student) do
      send_resp(conn, :no_content, "")
    end
  end

  def dropout(conn, params) do
    %{
      "start_date" => dropout_start_date,
      "academic_year" => academic_year
    } = params

    # Get student by either student_id or apaar_id
    # Expects params to contain either "student_id" or "apaar_id" key
    # Falls back to apaar_id if student_id is not provided or empty
    student = Users.get_student_by_id_or_apaar_id(params)

    case student do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Student not found with the provided identifier"})

      student ->
        case DropoutService.process_dropout(student, dropout_start_date, academic_year) do
          {:ok, updated_student} ->
            render(conn, :show, student: updated_student)

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{errors: reason})
        end
    end
  end

  def re_enroll(conn, params) do
    # Get student by either student_id or apaar_id
    student = Users.get_student_by_id_or_apaar_id(params)

    case student do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Student not found with the provided identifier"})

      student ->
        case ReEnrollmentService.process_re_enrollment(student, params) do
          {:ok, updated_student} ->
            render(conn, :show, student: updated_student)

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{errors: reason})
        end
    end
  end

  def enrolled(conn, params) do
    # Retrieve the student information based on the provided student ID
    student = Users.get_student_by_student_id(params["student_id"])
    user_id = student.user_id

    # Retrieve the group user information based on the user ID
    group_users = GroupUsers.get_group_user_by_user_id(user_id)

    # Get start_date from params instead of using current time
    start_date = params["start_date"]

    # Get batch information and enrolled status information
    {batch_group_id, batch_id, batch_group_type} =
      BatchEnrollmentService.get_batch_info(params["batch_id"])

    {status_id, status_group_type} = BatchEnrollmentService.get_enrolled_status_info()

    academic_year = params["academic_year"]

    # Check if the student is already enrolled in the specified batch
    unless BatchEnrollmentService.existing_batch_enrollment?(user_id, batch_id) do
      BatchEnrollmentService.handle_batch_enrollment(
        user_id,
        batch_id,
        batch_group_type,
        academic_year,
        start_date
      )

      # Handle the enrollment process for the status
      BatchEnrollmentService.handle_status_enrollment(
        user_id,
        status_id,
        status_group_type,
        academic_year,
        start_date
      )
    end

    # Only handle grade if it's provided in the params
    if Map.has_key?(params, "grade") do
      {grade_group_id, grade_id, grade_group_type} =
        BatchEnrollmentService.get_grade_info(params["grade"])

      # Check if grade has changed
      if BatchEnrollmentService.grade_changed?(user_id, grade_id) do
        # Handle grade enrollment
        BatchEnrollmentService.handle_grade_enrollment(
          user_id,
          grade_id,
          grade_group_type,
          academic_year,
          start_date
        )

        # Update grade in group_user
        BatchEnrollmentService.update_grade_user(user_id, grade_group_id, group_users)

        # Update grade in student table
        BatchEnrollmentService.update_student_grade(student, grade_id)
      end
    end

    # Always update the batch group user
    BatchEnrollmentService.update_batch_user(user_id, batch_group_id, group_users)

    # Update the student's status to "enrolled" and render the response
    with {:ok, %Student{} = updated_student} <-
           Users.update_student(student, %{"status" => "enrolled"}) do
      render(conn, :show, student: updated_student)
    end
  end

  swagger_path :create_student_id do
    post("/api/student/generate-id")

    parameters do
      body(:body, Schema.ref(:StudentIdGeneration), "Details for generating student ID",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentIdGenerationResponse))
  end

  def create_student_id(conn, params) do
    case generate_student_id(params) do
      {:ok, student_id} ->
        conn
        |> put_status(:created)
        |> json(%{student_id: student_id})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp generate_student_id(params) do
    grade = Grades.get_grade_by_params(%{number: params["grade"]})

    existing_students =
      Users.get_students_with_users(
        grade.id,
        params["category"],
        params["date_of_birth"],
        params["gender"],
        params["first_name"]
      )

    case find_existing_student_id(existing_students, params) do
      {:ok, ""} ->
        generate_new_student_id(params)

      {:ok, student_id} ->
        {:ok, student_id}

      {:error, message} ->
        {:error, message}
    end
  end

  defp find_existing_student_id(existing_students, params) do
    Enum.reduce_while(existing_students, {:ok, ""}, fn {student, user}, acc ->
      case check_enrollment_and_get_id(user, student.student_id, params) do
        {:ok, nil} -> {:cont, acc}
        {:ok, student_id} -> {:halt, {:ok, student_id}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp check_enrollment_and_get_id(user, student_id, params) do
    region = if params["region"] == "", do: nil, else: params["region"]

    case Schools.get_school_by_params(%{name: params["school_name"], region: region}) do
      [] ->
        {:error, "No school found with the given name and region"}

      [school] ->
        if check_existing_enrollment(user.id, school.id) do
          {:ok, student_id}
        else
          {:ok, nil}
        end

      _ ->
        {:error, "multiple school found with the given name and region"}
    end
  end

  defp check_existing_enrollment(user_id, school_id) do
    enrollment =
      EnrollmentRecords.get_enrollment_record_by_params(%{
        group_id: school_id,
        group_type: "school",
        user_id: user_id
      })

    enrollment != []
  end

  defp generate_new_student_id(params) do
    counter = 1000

    case get_school_code(params) do
      {:ok, school_code} ->
        try_generate_id(counter, params, school_code)

      {:error, message} ->
        {:error, message}
    end
  end

  defp try_generate_id(0, _params, _school_code) do
    {:error, "Student ID could not be generated. Max attempts hit!"}
  end

  defp try_generate_id(attempts_left, params, school_code) do
    id = generate_new_id(params, school_code)

    if check_if_generated_id_already_exists(id) do
      try_generate_id(attempts_left - 1, params, school_code)
    else
      {:ok, id}
    end
  end

  defp generate_new_id(params, school_code) do
    grade = String.to_integer(params["grade"])
    class_code = get_class_code(grade)
    three_digit_code = generate_three_digit_code()

    class_code <> school_code <> three_digit_code
  end

  defp get_class_code(grade) do
    {current_year, current_month, _day} = :calendar.local_time() |> elem(0)

    academic_year = if current_month < 4, do: current_year - 1, else: current_year

    graduating_year = academic_year + (12 - grade) + 1

    graduating_year
    |> Integer.to_string()
    |> String.slice(-2..-1)
  end

  defp get_school_code(params) do
    region = if params["region"] == "", do: nil, else: params["region"]

    case Schools.get_school_by_params(%{region: region, name: params["school_name"]}) do
      [] ->
        {:error, "No school found with the given name and region"}

      [school] ->
        {:ok, school.code}

      _ ->
        {:error, "multiple school found with the given name and region"}
    end
  end

  defp generate_three_digit_code do
    Enum.reduce(1..3, "", fn _, acc ->
      acc <> Integer.to_string(:rand.uniform(10) - 1)
    end)
  end

  defp check_if_generated_id_already_exists(id) do
    case Users.get_student_by_student_id(id) do
      nil -> false
      _ -> true
    end
  end

  # function to verify student data with the values recieved in the verification params
  swagger_path :verify_student do
    post("/api/student/verify-student")

    parameters do
      body(:body, Schema.ref(:VerifyStudentRequest), "Parameters needed to verify student",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:VerificationResult))
  end

  def verify_student(conn, %{
        "student_id" => student_id,
        "verification_params" => verification_params
      }) do
    case get_student_and_user(student_id) do
      {:ok, student, user} ->
        student_exists = verify_student_and_user_data(student, user, verification_params)

        conn
        |> put_status(:ok)
        |> json(%{is_verified: student_exists})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Student not found"})
    end
  end

  defp get_student_and_user(student_id) do
    case Users.get_student_by_student_id(student_id) do
      nil ->
        {:error, :not_found}

      student ->
        case Users.get_user!(student.user_id) do
          nil ->
            {:error, :not_found}

          user ->
            {:ok, student, user}
        end
    end
  end

  defp verify_student_and_user_data(student, user, verification_params) do
    Enum.all?(verification_params, fn {key, value} ->
      cond do
        key == "auth_group_id" ->
          verify_auth_group(user.id, value)

        key == "date_of_birth" ->
          user_dob = Map.get(user, String.to_existing_atom(key))
          parsed_value = Date.from_iso8601!(value)
          Date.compare(user_dob, parsed_value) == :eq

        Map.has_key?(student, String.to_existing_atom(key)) ->
          Map.get(student, String.to_existing_atom(key)) == value

        Map.has_key?(user, String.to_existing_atom(key)) ->
          Map.get(user, String.to_existing_atom(key)) == value

        true ->
          false
      end
    end)
  end

  def verify_auth_group(user_id, auth_group_id) do
    case Groups.get_group_by_child_id_and_type(auth_group_id, "auth_group") do
      nil ->
        false

      group ->
        case GroupUsers.get_group_user_by_user_id_and_group_id(user_id, group.id) do
          nil ->
            false

          _group_user ->
            true
        end
    end
  end

  def update_user_enrollment_records(conn, params) do
    with student when not is_nil(student) <-
           Users.get_student_by_student_id(params["student_id"]),
         user_id <- student.user_id,
         group_id <- params["group_id"],
         group_type <- params["group_type"] do
      update_attrs = Map.drop(params, ["student_id", "group_id", "group_type"])

      enrollment_response = update_enrollment_record(user_id, group_id, group_type, update_attrs)

      status_response =
        if group_type == "batch" do
          update_status_record(user_id, update_attrs)
        else
          nil
        end

      conn
      |> put_status(:ok)
      |> json(%{
        message: "Enrollment records updated.",
        updated_record: enrollment_response,
        updated_status_record: status_response
      })
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Student not found"})
    end
  end

  defp update_enrollment_record(user_id, group_id, group_type, attrs) do
    case Repo.get_by(EnrollmentRecord,
           user_id: user_id,
           group_id: group_id,
           group_type: group_type
         ) do
      nil ->
        %{error: "Enrollment record not found for given group_type and group_id"}

      record ->
        case EnrollmentRecords.update_enrollment_record(record, attrs) do
          {:ok, updated} ->
            EnrollmentRecordJSON.show(%{enrollment_record: updated})

          {:error, _changeset} ->
            %{error: "Failed to update enrollment record"}
        end
    end
  end

  defp update_status_record(user_id, attrs) do
    case Repo.get_by(EnrollmentRecord,
           user_id: user_id,
           group_type: "status",
           is_current: true
         ) do
      nil ->
        %{error: "Status record not found"}

      record ->
        case EnrollmentRecords.update_enrollment_record(record, attrs) do
          {:ok, updated} ->
            EnrollmentRecordJSON.show(%{enrollment_record: updated})

          {:error, _changeset} ->
            %{error: "Failed to update status record"}
        end
    end
  end

  @doc """
  This function removes the dropout status from both the enrollment records and the student table.
  """
  def remove_dropout_status(conn, %{"student_id" => student_id}) do
    with {:ok, student} <- get_student(student_id),
         enrollment_records <-
           EnrollmentRecords.get_enrollment_records_by_user_id(student.user_id),
         status_record <- find_status_record(enrollment_records),
         {:ok, _} <- handle_status_record(status_record),
         {:ok, _} <- update_current_status(enrollment_records),
         {:ok, _} <- set_student_status_to_null(student) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Student status updated successfully"})
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  defp get_student(student_id) do
    case Users.get_student_by_student_id(student_id) do
      nil -> {:error, "Student not found"}
      student -> {:ok, student}
    end
  end

  defp find_status_record(enrollment_records) do
    Enum.find(enrollment_records, &(&1.group_type == "status"))
  end

  defp handle_status_record(status_record) do
    status = Statuses.get_status!(status_record.group_id)

    if status.title == :dropout do
      case EnrollmentRecords.delete_enrollment_record(status_record) do
        {:ok, _deleted_record} ->
          {:ok, "Record deleted successfully"}

        {:error, changeset} ->
          {:error, "Failed to delete record: #{inspect(changeset.errors)}"}
      end
    else
      {:ok, status_record}
    end
  end

  defp update_current_status(enrollment_records) do
    Enum.reduce_while(enrollment_records, {:ok, []}, fn record, {:ok, updated_records} ->
      case EnrollmentRecords.update_enrollment_record(record, %{is_current: true}) do
        {:ok, updated_record} -> {:cont, {:ok, [updated_record | updated_records]}}
        {:error, _} -> {:halt, {:error, "Failed to update enrollment record"}}
      end
    end)
  end

  defp set_student_status_to_null(student) do
    Users.update_student(student, %{status: nil})
  end

  def batch_process(conn, %{"data" => batch_data}) do
    results = Enum.map(batch_data, &process_student(&1))

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    conn
    |> put_status(:ok)
    |> render(:batch_result, %{
      message: "Batch processing completed",
      successful: successful,
      failed: failed,
      results: results
    })
  end

  defp process_student(student_data) do
    student_data =
      if Map.has_key?(student_data, "grade") do
        grade = Grades.get_grade_by_number(student_data["grade"])

        # Merge the fetched grade_id into student_data if grade is found
        Map.merge(student_data, %{"grade_id" => grade.id})
      else
        student_data
      end

    case Users.get_student_by_student_id(student_data["student_id"]) do
      nil ->
        case Users.create_student_with_user(student_data) do
          {:ok, student} ->
            {:ok, student}

          {:error, _changeset} ->
            {:error,
             %{
               student_id: student_data["student_id"],
               message: "Failed to create student with user. Some problem with changeset"
             }}
        end

      existing_student ->
        user = Users.get_user!(existing_student.user_id)

        case Users.update_student_with_user(existing_student, user, student_data) do
          {:ok, student} ->
            {:ok, student}

          {:error, _changeset} ->
            {:error,
             %{
               student_id: student_data["student_id"],
               message: "Failed to update student with user. Some problem with changeset"
             }}
        end
    end
  end

  def get_schema(conn, _params) do
    # Get the list of student fields dynamically from the Student schema
    student_fields = get_fields(Student)

    # Get the list of user fields dynamically from the User schema
    user_fields = get_fields(User)

    combined_fields = student_fields ++ user_fields

    # Return the schema as a JSON response
    json(conn, %{"fields" => combined_fields})
  end

  defp get_fields(module) do
    module.__schema__(:fields)
    |> Enum.map(&Atom.to_string/1)
  end

  swagger_path :update_student_status do
    post("/api/student/{student_id}/status")

    parameters do
      student_id(:path, :string, "The student_id of the student", required: true)
      status(:query, :string, "The status to be updated", required: true)
      academic_year(:query, :string, "The academic year", required: true)
      start_date(:query, :string, "The start date for the status", required: true)
    end

    response(200, "OK", Schema.ref(:Student))
    response(400, "Bad Request")
    response(404, "Not Found")
  end

  def update_student_status(conn, params) do
    with {:ok, status} <- get_status_by_title(params["status"]),
         student when not is_nil(student) <-
           Users.get_student_by_student_id(params["student_id"]),
         :ok <- check_existing_status(student, status.title),
         {:ok, %Student{} = updated_student} <- update_student_status_field(student, status),
         {:ok, _enrollment_record} <- create_status_enrollment_record(student, status, params) do
      conn
      |> put_status(:ok)
      |> render(:show, student: updated_student)
    else
      {:error, :status_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Status not found"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Student not found"})

      {:error, :status_already_assigned} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Student already has the requested status"})

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to update status", details: changeset.errors})
    end
  end

  # Helper function to check if student already has the status
  defp check_existing_status(student, status_title) do
    case student.status == Atom.to_string(status_title) do
      true -> {:error, :status_already_assigned}
      false -> :ok
    end
  end

  # Helper function to get status by title
  defp get_status_by_title(status_title) do
    case Statuses.get_status_by_title(status_title) do
      nil -> {:error, :status_not_found}
      status -> {:ok, status}
    end
  end

  # Helper function to update student status
  defp update_student_status_field(student, status) do
    Users.update_student(student, %{status: Atom.to_string(status.title)})
  end

  # Helper function to create new enrollment record
  defp create_status_enrollment_record(student, status, params) do
    # First, update any existing status enrollment records to is_current: false
    update_existing_status_enrollments(student.user_id, params["start_date"])

    enrollment_attrs = %{
      user_id: student.user_id,
      group_id: status.id,
      group_type: "status",
      grade_id: student.grade_id,
      academic_year: params["academic_year"],
      start_date: params["start_date"],
      is_current: true
    }

    EnrollmentRecords.create_enrollment_record(enrollment_attrs)
  end

  # Helper function to close the current status enrollment record for a user
  # This sets `is_current` to false and updates the `end_date` for the record
  defp update_existing_status_enrollments(user_id, end_date) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == "status" and e.is_current == true,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])

    {:ok, :updated}
  end

  @doc """
  Creates a new student with user data and all enrollment records.
  This endpoint is designed for external services to create students with full enrollment setup.

  Expected params:
  - Student fields: student_id, apaar_id, category, etc.
  - User fields: first_name, last_name, phone, email, date_of_birth, gender, etc.
  - Enrollment fields: auth_group, school_code, batch_id, grade, academic_year, start_date

  Note: If grade number is provided, it will be automatically converted to grade_id.

  Returns the created student with user data or error details.
  """
  swagger_path :create_with_enrollments do
    post("/api/student/create-with-enrollments")

    parameters do
      body(:body, Schema.ref(:StudentWithEnrollments), "Student with user and enrollment data",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentWithUser))
    response(400, "Bad Request")
    response(422, "Unprocessable Entity")
  end

  def create_with_enrollments(conn, params) do
    # Validate required enrollment fields and convert grade to grade_id
    with :ok <- validate_enrollment_params(params),
         {:ok, enriched_params} <- enrich_params_with_grade_id(params),
         {:ok, student} <- Users.create_or_update_student(enriched_params),
         student <- Dbservice.Repo.preload(student, [:user]),
         {:ok, _enrollments} <- create_student_enrollments(student.user, enriched_params) do
      conn
      |> put_status(:created)
      |> render(:show, student: student)
    else
      {:error, :missing_enrollment_fields, missing} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Missing required enrollment fields",
          missing_fields: missing
        })

      {:error, :grade_not_found, grade} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Grade not found",
          grade: grade,
          message: "No grade found with number: #{grade}"
        })

      {:error, :student_exists, student} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Student already exists",
          student_id: student.student_id,
          apaar_id: student.apaar_id,
          message:
            "Use the update endpoint or student_update import type to modify existing students"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Validation failed",
          details: ChangesetFormatter.map_errors(changeset)
        })

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  # Validates that required enrollment fields are present
  defp validate_enrollment_params(params) do
    required_fields = ["academic_year", "start_date"]
    optional_enrollment_fields = ["auth_group", "school_code", "batch_id", "grade"]

    missing_required =
      Enum.filter(required_fields, fn field ->
        is_nil(params[field]) || params[field] == ""
      end)

    # Check if at least one enrollment field is present
    has_enrollment_field =
      Enum.any?(optional_enrollment_fields, fn field ->
        not is_nil(params[field]) && params[field] != ""
      end)

    cond do
      length(missing_required) > 0 ->
        {:error, :missing_enrollment_fields, missing_required}

      not has_enrollment_field ->
        {:error, :missing_enrollment_fields,
         ["At least one of: auth_group, school_code, batch_id, or grade must be provided"]}

      true ->
        :ok
    end
  end

  # Enriches params by converting grade number to grade_id if grade is provided
  defp enrich_params_with_grade_id(params) do
    case Map.get(params, "grade") do
      nil ->
        # No grade provided, return params as-is
        {:ok, params}

      grade when is_binary(grade) or is_integer(grade) ->
        # Convert to integer if string
        grade_number = if is_binary(grade), do: String.to_integer(grade), else: grade

        case Grades.get_grade_by_number(grade_number) do
          nil ->
            {:error, :grade_not_found, grade_number}

          grade_record ->
            # Add grade_id to params
            {:ok, Map.put(params, "grade_id", grade_record.id)}
        end

      _ ->
        # Invalid grade format
        {:ok, params}
    end
  end

  # Creates all enrollment records for the student
  defp create_student_enrollments(user, params) do
    Dbservice.DataImport.StudentEnrollment.create_enrollments(user, params)
  end
end
