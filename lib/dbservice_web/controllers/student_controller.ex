defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Student
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Statuses.Status
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Student, as: SwaggerSchemaStudent

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        SwaggerSchemaStudent.student(),
        SwaggerSchemaStudent.students()
      ),
      Map.merge(
        SwaggerSchemaStudent.student_registration(),
        SwaggerSchemaStudent.student_with_user()
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

  def dropout(conn, %{"student_id" => student_id}) do
    student = Users.get_student_by_student_id(student_id)

    # Check if the student's status is already 'dropout'
    if student.status == "dropout" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Student is already marked as dropout"})
    else
      user_id = student.user_id
      current_time = DateTime.utc_now()

      # Fetch status and group details in a single query
      {group_id, group_type} =
        from(s in Status,
          join: g in Group,
          on: g.child_id == s.id and g.type == "status",
          where: s.title == :dropout,
          select: {g.id, g.type}
        )
        |> Repo.one()

      # Fetch all current enrollment records for the user
      current_enrollments =
        from(e in EnrollmentRecord,
          where: e.user_id == ^user_id and e.is_current == true
        )
        |> Repo.all()

      # Use the academic_year and grade_id from one of the current enrollments
      %{academic_year: academic_year, grade_id: grade_id} = List.first(current_enrollments)

      # Update all current enrollment records to set is_current: false and end_date
      Enum.each(current_enrollments, fn enrollment ->
        EnrollmentRecords.update_enrollment_record(enrollment, %{
          is_current: false,
          end_date: current_time
        })
      end)

      # Create a new enrollment record with the fetched group_id
      new_enrollment_attrs = %{
        user_id: user_id,
        is_current: true,
        start_date: current_time,
        group_id: group_id,
        group_type: group_type,
        academic_year: academic_year,
        grade_id: grade_id
      }

      EnrollmentRecords.create_enrollment_record(new_enrollment_attrs)

      # Delete all group-user entries for the user
      from(gu in GroupUser, where: gu.user_id == ^user_id)
      |> Repo.delete_all()

      # Update the student's status to 'dropout' using update_student/2
      with {:ok, %Student{} = updated_student} <-
             Users.update_student(student, %{"status" => "dropout"}) do
        render(conn, "show.json", student: updated_student)
      end
    end
  end
end
