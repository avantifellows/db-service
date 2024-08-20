defmodule DbserviceWeb.TeacherProfileController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Profiles
  alias Dbservice.Profiles.TeacherProfile

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.TeacherProfile, as: SwaggerSchemaTeacherProfile

  def swagger_definitions do
    Map.merge(
      Map.merge(
        SwaggerSchemaTeacherProfile.teacher_profile(),
        SwaggerSchemaTeacherProfile.teacher_profiles()
      ),
      Map.merge(
        SwaggerSchemaTeacherProfile.teacher_profile_setup(),
        SwaggerSchemaTeacherProfile.teacher_profile_with_user_profile()
      )
    )
  end

  swagger_path :index do
    get("/api/teacher-profile")

    parameters do
      params(:query, :string, "The id of the teacher",
        required: false,
        name: "teacher_id"
      )
    end

    response(200, "OK", Schema.ref(:TeacherProfiles))
  end

  def index(conn, params) do
    query =
      from m in TeacherProfile,
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

    teacher_profile = Repo.all(query) |> Repo.preload([:user_profile])
    render(conn, "index.json", teacher_profile: teacher_profile)
  end

  swagger_path :show do
    get("/api/teacher-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher profile record", required: true)
    end

    response(200, "OK", Schema.ref(:TeacherProfileWithUserProfile))
  end

  def show(conn, %{"id" => id}) do
    teacher_profile = Profiles.get_teacher_profile!(id)
    render(conn, "show.json", teacher_profile: teacher_profile)
  end

  swagger_path :update do
    patch("/api/teacher-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher profile record", required: true)
      body(:body, Schema.ref(:TeacherProfileSetup), "Teacher Profile to update", required: true)
    end

    response(200, "Updated", Schema.ref(:TeacherProfileWithUserProfile))
  end

  def update(conn, params) do
    teacher_profile = Profiles.get_teacher_profile!(params["id"])
    user_profile = Profiles.get_user_profile!(teacher_profile.user_profile_id)

    with {:ok, %TeacherProfile{} = teacher_profile} <-
           Profiles.update_teacher_profile_with_user_profile(
             teacher_profile,
             user_profile,
             params
           ) do
      render(conn, "show.json", teacher_profile: teacher_profile)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/teacher-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher profile record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    teacher_profile = Profiles.get_teacher_profile!(id)

    with {:ok, %TeacherProfile{}} <- Profiles.delete_teacher_profile(teacher_profile) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :create do
    post("/api/teacher-profile")

    parameters do
      body(
        :body,
        Schema.ref(:TeacherProfileSetup),
        "TeacherProfile to setup along with user profile",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:TeacherProfileWithUserProfile))
  end

  def create(conn, params) do
    teacher = Users.get_teacher_by_teacher_id(params["teacher_id"])
    teacher_fk = teacher.id
    user_id = teacher.user_id

    updated_params =
      params
      |> Map.put_new("user_id", user_id)
      |> Map.put_new("teacher_fk", teacher_fk)

    case Profiles.get_profile_by_teacher_id(updated_params["teacher_id"]) do
      nil ->
        create_new_profile(conn, updated_params)

      existing_profile ->
        update_existing_profile(conn, existing_profile, updated_params)
    end
  end

  defp create_new_profile(conn, params) do
    with {:ok, %TeacherProfile{} = teacher_profile} <- Profiles.create_teacher_profile(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.teacher_profile_path(conn, :show, teacher_profile))
      |> render("show.json", teacher_profile: teacher_profile)
    end
  end

  defp update_existing_profile(conn, existing_profile, params) do
    user_profile = Profiles.get_user_profile!(teacher_profile.user_profile_id)

    with {:ok, %TeacherProfile{} = teacher_profile} <-
           Profiles.update_teacher_profile(existing_profile, user_profile, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", teacher_profile: teacher_profile)
    end
  end
end
