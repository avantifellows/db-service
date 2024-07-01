defmodule DbserviceWeb.StudentController do
  alias Hex.HTTP
  alias Dbservice.EnrollmentRecords
  alias Dbservice.Schools
  alias Dbservice.Grades
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Student

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

  swagger_path :create_student_id do
    post("/api/student/generate_id")

    parameters do
      body(:body, Schema.ref(:StudentIdGeneration), "Details for generating student ID",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentIdGenerationResponse))
  end

  def create_student_id(conn, params) do
    try do
      case generate_student_id(params) do
        "" ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Could not create student id"})

        student_id ->
          conn
          |> put_status(:created)
          |> json(%{student_id: student_id})
      end
    rescue
      e in RuntimeError ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: e.message})

      e in _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "An unexpected error occurred: #{inspect(e)}"})
    end
  end

  defp generate_student_id(params) do
    grade_id = Grades.get_grade_id_by_number(params["grade"])
    # existing_students = Users.get_students_by_grade_and_category(grade_id, params["category"])
    existing_students =
      Users.get_students_by_params(%{grade_id: grade_id, category: params["category"]})

    student_id =
      if Enum.empty?(existing_students) do
        ""
      else
        Enum.find_value(existing_students, "", fn existing_student ->
          existing_user =
            Users.get_user_by_params(%{
              id: existing_student.user_id,
              date_of_birth: params["date_of_birth"],
              gender: params["gender"],
              first_name: params["first_name"]
            })

          if Enum.empty?(existing_user) do
            nil
          else
            school = Schools.get_school_by_params(%{name: params["school_name"]})

            existing_enrollment_record =
              Enum.any?(existing_user, fn user ->
                EnrollmentRecords.get_enrollment_record_by_params(%{
                  group_id: school.id,
                  group_type: "school",
                  user_id: user.id
                })
              end)

            if existing_enrollment_record do
              existing_student.student_id
            else
              nil
            end
          end
        end)
      end

    if student_id == "" do
      counter = 1000

      generated_id =
        Enum.reduce_while(1..counter, nil, fn _, acc ->
          if acc do
            {:halt, acc}
          else
            id = generate_new_id(params)

            if check_if_generated_id_already_exists(id) do
              {:cont, nil}
            else
              {:halt, id}
            end
          end
        end)

      if generated_id do
        generated_id
      else
        raise RuntimeError, message: "JNV Student ID could not be generated. Max loops hit!"
      end
    else
      student_id
    end
  end

  defp generate_new_id(params) do
    class_code = get_class_code(params["grade"])
    jnv_code = get_jnv_code(params)
    three_digit_code = generate_three_digit_code()

    IO.puts(
      "Debug: class_code: #{class_code}, jnv_code: #{jnv_code}, three_digit_code: #{three_digit_code}"
    )

    class_code <> jnv_code <> three_digit_code
  end

  defp get_class_code(grade) do
    IO.puts("Debug: grade type is #{inspect(grade)}")

    current_year =
      :calendar.local_time()
      |> elem(0)
      |> elem(0)

    IO.puts("Debug: current_year is #{current_year}")

    graduating_year = current_year + (12 - grade)
    IO.puts("Debug: graduating_year is #{graduating_year}")

    graduating_year
    |> Integer.to_string()
    |> String.slice(-2..-1)
  end

  defp get_jnv_code(params) do
    case Schools.get_school_by_params(%{region: params["region"], name: params["school_name"]}) do
      nil ->
        raise RuntimeError,
          message:
            "School not found for region: #{params["region"]}, name: #{params["school_name"]}"

      school ->
        IO.puts("Debug: School found: #{inspect(school)}")
        school.code
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
end
