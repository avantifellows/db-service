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
  alias Dbservice.Statuses.Status
  alias Dbservice.Groups.Group
  alias Dbservice.Batches.Batch
  alias Dbservice.GroupUsers
  alias Dbservice.Grades.Grade
  alias DbserviceWeb.EnrollmentRecordView
  alias Dbservice.Statuses

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
        ),
        Map.merge(
          Map.merge(
            SwaggerSchemaStudent.verify_student_request(),
            SwaggerSchemaStudent.verification_result()
          ),
          SwaggerSchemaStudent.verification_params()
        )
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
    render(conn, "index.json", student: student)
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
    case Users.get_student_by_student_id(params["student_id"]) do
      nil ->
        create_student_with_user(conn, params)

      existing_student ->
        update_existing_student_with_user(conn, existing_student, params)
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
    student = Users.get_student!(id)
    render(conn, "show.json", student: student)
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
    user = Users.get_user!(student.user_id)

    with {:ok, %Student{} = student} <- Users.update_student_with_user(student, user, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", student: student)
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

  defp update_existing_student_with_user(conn, existing_student, params) do
    user = Users.get_user!(existing_student.user_id)

    with {:ok, %Student{} = student} <-
           Users.update_student_with_user(existing_student, user, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", student: student)
    end
  end

  defp create_student_with_user(conn, params) do
    with {:ok, %Student{} = student} <- Users.create_student_with_user(params) do
      conn
      |> put_status(:created)
      |> render("show.json", student: student)
    end
  end

  def dropout(conn, %{
        "student_id" => student_id,
        "start_date" => dropout_start_date,
        "academic_year" => academic_year
      }) do
    student = Users.get_student_by_student_id(student_id)

    # Check if the student's status is already 'dropout'
    if student.status == "dropout" do
      conn
      |> put_status(:bad_request)
      |> json(%{errors: "Student is already marked as dropout"})
    else
      user_id = student.user_id

      # Fetch status and group details in a single query
      {status_id, group_type} =
        from(s in Status,
          join: g in Group,
          on: g.child_id == s.id and g.type == "status",
          where: s.title == :dropout,
          select: {g.child_id, g.type}
        )
        |> Repo.one()

      # Fetch all current enrollment records for the user
      current_enrollments =
        from(e in EnrollmentRecord,
          where: e.user_id == ^user_id and e.is_current == true
        )
        |> Repo.all()

      # Get grade_id from the student table
      grade_id = student.grade_id

      Enum.each(current_enrollments, fn enrollment ->
        EnrollmentRecords.update_enrollment_record(enrollment, %{
          is_current: false,
          end_date: dropout_start_date
        })
      end)

      # Create a new enrollment record with the fetched status_id
      new_enrollment_attrs = %{
        user_id: user_id,
        is_current: true,
        start_date: dropout_start_date,
        group_id: status_id,
        group_type: group_type,
        academic_year: academic_year,
        grade_id: grade_id
      }

      EnrollmentRecords.create_enrollment_record(new_enrollment_attrs)

      # Delete all group-user entries for the user
      # NOTE: Commenting these lines because we don't want to stop
      # students from logging in once they are marked as dropout(s)
      # in case they want to re-enroll in the future.
      #
      # from(gu in GroupUser, where: gu.user_id == ^user_id)
      # |> Repo.delete_all()

      # Update the student's status to 'dropout' using update_student/2
      with {:ok, %Student{} = updated_student} <-
             Users.update_student(student, %{"status" => "dropout"}) do
        render(conn, "show.json", student: updated_student)
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
    {batch_group_id, batch_id, batch_group_type} = get_batch_info(params["batch_id"])
    {status_id, status_group_type} = get_enrolled_status_info()

    academic_year = params["academic_year"]

    # Check if the student is already enrolled in the specified batch
    unless existing_batch_enrollment?(user_id, batch_id) do
      handle_batch_enrollment(
        user_id,
        batch_id,
        batch_group_type,
        academic_year,
        start_date
      )

      # Handle the enrollment process for the status
      handle_status_enrollment(
        user_id,
        status_id,
        status_group_type,
        academic_year,
        start_date
      )
    end

    # Only handle grade if it's provided in the params
    if Map.has_key?(params, "grade") do
      {grade_group_id, grade_id, grade_group_type} = get_grade_info(params["grade"])

      # Fetch current grade from database to compare
      current_grade = EnrollmentRecords.get_current_grade_id(user_id)
      grade_changed = current_grade != grade_id

      # If grade has changed, create a new grade entry in ER
      if grade_changed do
        handle_grade_change(user_id, grade_id, start_date, academic_year, grade_group_type)

        # Update grade in group_user
        update_group_user_grade(user_id, grade_group_id, group_users)

        # Update grade in student table
        update_student_grade(student, grade_id)
      end
    end

    # Always update the batch group user
    update_batch_user(user_id, batch_group_id, group_users)

    # Update the student's status to "enrolled" and render the response
    with {:ok, %Student{} = updated_student} <-
           Users.update_student(student, %{"status" => "enrolled"}) do
      render(conn, "show.json", student: updated_student)
    end
  end

  # Handle grade change by creating a new grade entry in ER
  defp handle_grade_change(user_id, grade_id, start_date, academic_year, grade_group_type) do
    # First mark all current grade entries as not current
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == "grade" and e.is_current == true,
      update: [set: [is_current: false, end_date: ^start_date]]
    )
    |> Repo.update_all([])

    # Create new grade enrollment record
    EnrollmentRecords.create_enrollment_record(%{
      user_id: user_id,
      is_current: true,
      start_date: start_date,
      group_id: grade_id,
      group_type: grade_group_type,
      academic_year: academic_year
    })
  end

  # Update grade in group_user
  defp update_group_user_grade(user_id, grade_group_id, group_users) do
    grade_group_user = Enum.find(group_users, &group_user_by_type?(&1, "grade"))

    if grade_group_user do
      GroupUsers.update_group_user(grade_group_user, %{group_id: grade_group_id})
    else
      # Create a new grade group user if one doesn't exist
      GroupUsers.create_group_user(%{
        user_id: user_id,
        group_id: grade_group_id
      })
    end
  end

  # Update grade in student table
  defp update_student_grade(student, grade_id) do
    Users.update_student(student, %{"grade_id" => grade_id})
  end

  # Fetches batch information based on the batch ID
  defp get_batch_info(batch_id) do
    from(b in Batch,
      join: g in Group,
      on: g.child_id == b.id and g.type == "batch",
      where: b.batch_id == ^batch_id,
      select: {g.id, g.child_id, g.type}
    )
    |> Repo.one()
  end

  # Fetches grade information based on the grade number
  defp get_grade_info(grade) do
    from(gr in Grade,
      join: g in Group,
      on: g.child_id == gr.id and g.type == "grade",
      where: gr.number == ^grade,
      select: {g.id, g.child_id, g.type}
    )
    |> Repo.one()
  end

  # Fetches enrolled status information
  defp get_enrolled_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :enrolled,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  # Checks if the student is already enrolled in the batch
  defp existing_batch_enrollment?(user_id, batch_id) do
    from(e in EnrollmentRecord,
      where:
        e.user_id == ^user_id and e.group_id == ^batch_id and e.group_type == "batch" and
          e.is_current == true
    )
    |> Repo.exists?()
  end

  # Handles batch enrollment process
  defp handle_batch_enrollment(
         user_id,
         batch_id,
         group_type,
         academic_year,
         start_date
       ) do
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

  # Handles status enrollment process
  defp handle_status_enrollment(
         user_id,
         status_id,
         status_group_type,
         academic_year,
         start_date
       ) do
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

  # Updates existing enrollments to mark them as not current
  defp update_existing_enrollments(user_id, group_type, start_date) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true,
      update: [set: [is_current: false, end_date: ^start_date]]
    )
    |> Repo.update_all([])
  end

  # Updates or creates a group user record for the batch
  defp update_batch_user(user_id, group_id, group_users) do
    batch_group_user = Enum.find(group_users, &group_user_by_type?(&1, "batch"))

    if batch_group_user do
      # Update existing group user with the new group ID
      GroupUsers.update_group_user(batch_group_user, %{group_id: group_id})
    else
      # Create a new group user record
      GroupUsers.create_group_user(%{user_id: user_id, group_id: group_id, type: "batch"})
    end
  end

  # Checks if a group user is associated with a specific type
  defp group_user_by_type?(group_user, type) do
    from(g in Group,
      where: g.id == ^group_user.group_id and g.type == ^type,
      select: g.id
    )
    |> Repo.exists?()
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
            EnrollmentRecordView.render("enrollment_record.json", %{enrollment_record: updated})

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
            EnrollmentRecordView.render("enrollment_record.json", %{enrollment_record: updated})

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
    |> render("batch_result.json", %{
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
         {:ok, student} <- get_student_by_student_id(params["student_id"]),
         :ok <- check_existing_status(student, status.title),
         {:ok, %Student{} = updated_student} <- update_student_status_field(student, status),
         {:ok, _enrollment_record} <- create_status_enrollment_record(student, status, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", student: updated_student)
    else
      {:error, :status_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Status not found"})

      {:error, :student_not_found} ->
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

  # Helper function to get student by student_id
  defp get_student_by_student_id(student_id) do
    case Users.get_student_by_student_id(student_id) do
      nil -> {:error, :student_not_found}
      student -> {:ok, student}
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

  def get_student_by_id(conn, %{"id" => id, "group" => group}) do
    student =
      cond do
        group == "EnableStudents" ->
          Repo.one(from s in Student, where: s.apaar_id == ^id) ||
            Repo.one(from s in Student, where: s.student_id == ^id)

        true ->
          Repo.one(from s in Student, where: s.student_id == ^id)
      end

    if student do
      render(conn, "show.json", student: student)
    else
      render(conn, "show.json", student: nil)
    end
  end
end
