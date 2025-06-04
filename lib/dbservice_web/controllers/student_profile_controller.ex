defmodule DbserviceWeb.StudentProfileController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
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
    json(conn, DbserviceWeb.StudentProfileJSON.index(%{student_profile: student_profile}))
  end

  swagger_path :show do
    get("/api/student-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the student profile record", required: true)
    end

    response(200, "OK", Schema.ref(:StudentProfileWithUserProfile))
  end

  def show(conn, %{"id" => id}) do
    student_profile = Profiles.get_student_profile!(id)

    json(
      conn,
      DbserviceWeb.StudentProfileJSON.show_student_profile_with_user_profile(%{
        student_profile: student_profile
      })
    )
  end

  swagger_path :update do
    patch("/api/student-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the student profile record", required: true)
      body(:body, Schema.ref(:StudentProfileSetup), "Student Profile to update", required: true)
    end

    response(200, "Updated", Schema.ref(:StudentProfileWithUserProfile))
  end

  def update(conn, params) do
    student_profile = Profiles.get_student_profile!(params["id"])
    user_profile = Profiles.get_user_profile!(student_profile.user_profile_id)

    with {:ok, %StudentProfile{} = student_profile} <-
           Profiles.update_student_profile_with_user_profile(
             student_profile,
             user_profile,
             params
           ) do
      json(
        conn,
        DbserviceWeb.StudentProfileJSON.show_student_profile_with_user_profile(%{
          student_profile: student_profile
        })
      )
    end
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

  swagger_path :create do
    post("/api/student-profile")

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

  def create(conn, params) do
    student = Users.get_student_by_student_id(params["student_id"])
    student_fk = student.id
    user_id = student.user_id

    updated_params =
      params
      |> Map.put_new("user_id", user_id)
      |> Map.put_new("student_fk", student_fk)

    with {:ok, %StudentProfile{} = student_profile} <-
           Profiles.create_student_profile_with_user_profile(updated_params) do
      conn
      |> put_status(:created)
      |> json(
        DbserviceWeb.StudentProfileJSON.show_student_profile_with_user_profile(%{
          student_profile: student_profile
        })
      )
    end
  end
end
