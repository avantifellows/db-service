defmodule DbserviceWeb.StudentProfileController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Profiles
  alias Dbservice.Profiles.StudentProfile

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.StudentProfile, as: SwaggerSchemaStudentProfile

  def swagger_definitions do
    Map.merge(
      Map.merge(
        SwaggerSchemaStudentProfile.student_profile(),
        SwaggerSchemaStudentProfile.student_profiles()
      ),
      Map.merge(
        SwaggerSchemaStudentProfile.student_profile_setup(),
        SwaggerSchemaStudentProfile.student_profile_with_user_profile()
      )
    )
  end

  swagger_path :index do
    get("/api/student-profile")

    parameters do
      params(:query, :string, "The id of the student",
        required: false,
        name: "student_id"
      )

      params(:query, :string, "The stream of student", required: false, name: "stream")
    end

    response(200, "OK", Schema.ref(:StudentProfiles))
  end

  def index(conn, params) do
    query =
      from m in StudentProfile,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    student_profile = Repo.all(query) |> Repo.preload([:user_profile])
    render(conn, "index.json", student_profile: student_profile)
  end

  swagger_path :create do
    post("/api/student-profile")

    parameters do
      body(:body, Schema.ref(:StudentProfile), "Student Profile to create", required: true)
    end

    response(201, "Created", Schema.ref(:StudentProfile))
  end

  def create(conn, params) do
    with {:ok, %StudentProfile{} = student_profile} <- Profiles.create_student_profile(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.student_profile_path(conn, :show, student_profile))
      |> render("show.json", student_profile: student_profile)
    end
  end

  swagger_path :show do
    get("/api/student-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the student profile record", required: true)
    end

    response(200, "OK", Schema.ref(:StudentProfile))
  end

  def show(conn, %{"id" => id}) do
    student_profile = Profiles.get_student_profile!(id)
    render(conn, "show.json", student_profile: student_profile)
  end

  def update(conn, params) do
    student_profile = Profiles.get_student_profile!(params["id"])

    with {:ok, %StudentProfile{} = student_profile} <-
           Profiles.update_student_profile(student_profile, params) do
      render(conn, "show.json", student_profile: student_profile)
    end
  end

  swagger_path :update do
    patch("/api/student-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the student profile record", required: true)
      body(:body, Schema.ref(:StudentProfile), "Student Profile to update", required: true)
    end

    response(200, "Updated", Schema.ref(:StudentProfile))
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/student-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the student profile record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    student_profile = Profiles.get_student_profile!(id)

    with {:ok, %StudentProfile{}} <- Profiles.delete_student_profile(student_profile) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :setup do
    post("/api/student-profile/setup")

    parameters do
      body(
        :body,
        Schema.ref(:StudentProfileSetup),
        "StudentProfile to setup along with user profile",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentProfileWithUserProfile))
  end

  def setup(conn, params) do
    with {:ok, %StudentProfile{} = student_profile} <-
           Profiles.create_student_profile_with_user_profile(params) do
      conn
      |> put_status(:created)
      |> render("show.json", student_profile: student_profile)
    end
  end

  def update_student_profile_with_user_profile(conn, params) do
    student_profile = Profiles.get_student_profile!(params["id"])
    user_profile = Profiles.get_user_profile!(student_profile.user_profile_id)

    with {:ok, %StudentProfile{} = student_profile} <-
           Profiles.update_student_profile_with_user_profile(
             student_profile,
             user_profile,
             params
           ) do
      conn
      |> put_status(:ok)
      |> render("show.json", student_profile: student_profile)
    end
  end
end
