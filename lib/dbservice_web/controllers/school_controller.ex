defmodule DbserviceWeb.SchoolController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Schools.School
  alias Dbservice.Users
  alias Dbservice.Users.User
  alias Dbservice.Utils.Util

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.School, as: SwaggerSchemaSchool

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaSchool.school(),
      SwaggerSchemaSchool.schools()
    )
  end

  swagger_path :index do
    get("/api/school")

    parameters do
      params(:query, :string, "The name the school",
        required: false,
        name: "name"
      )

      params(:query, :string, "The code the school", required: false, name: "code")
      params(:query, :string, "The udise code the school", required: false, name: "udise_code")
    end

    response(200, "OK", Schema.ref(:Schools))
  end

  def index(conn, %{"code" => code}) do
    school = Repo.all(from t in School, where: t.code == ^code, select: t, limit: 1)
    render(conn, :index, school: school)
  end

  def index(conn, params) do
    query =
      from m in School,
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

    school = Repo.all(query)
    render(conn, :index, school: school)
  end

  swagger_path :create do
    post("/api/school")

    parameters do
      body(:body, Schema.ref(:School), "School to create", required: true)
    end

    response(201, "Created", Schema.ref(:School))
  end

  def create(conn, params) do
    code = params["code"]

    if is_nil(code) do
      conn
      |> put_status(422)
      |> json(%{error: "School code is required"})
    else
      case Schools.get_school_by_code(code) do
        nil ->
          create_new_school(conn, params)

        existing_school ->
          update_existing_school(conn, existing_school, params)
      end
    end
  end

  swagger_path :show do
    get("/api/school/{schoolId}")

    parameters do
      schoolId(:path, :integer, "The id of the school record", required: true)
    end

    response(200, "OK", Schema.ref(:School))
  end

  def show(conn, %{"id" => id}) do
    school = Schools.get_school!(id)
    render(conn, :show, school: school)
  end

  swagger_path :update do
    patch("/api/school/{schoolId}")

    parameters do
      schoolId(:path, :integer, "The id of the school record", required: true)
      body(:body, Schema.ref(:School), "School to create", required: true)
    end

    response(200, "Updated", Schema.ref(:School))
  end

  def update(conn, params) do
    school = Schools.get_school!(params["id"])

    with {:ok, %School{} = school} <- Schools.update_school(school, params) do
      render(conn, :show, school: school)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/school/{schoolId}")

    parameters do
      schoolId(:path, :integer, "The id of the school record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    school = Schools.get_school!(id)

    with {:ok, %School{}} <- Schools.delete_school(school) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_school(conn, params) do
    with {:ok, %School{} = school} <- Schools.create_school(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/school/#{school}")
      |> render(:show, school: school)
    end
  end

  defp update_existing_school(conn, existing_school, params) do
    with {:ok, %School{} = school} <- Schools.update_school(existing_school, params),
         {:ok, _} <- update_users_for_school(school.id) do
      conn
      |> put_status(:ok)
      |> render(:show, school: school)
    end
  end

  def create_school_with_user(conn, params) do
    code = params["code"]

    if is_nil(code) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "School code is required"})
    else
      case Schools.get_school_by_code(params["code"]) do
        nil ->
          create_school_and_user(conn, params)

        existing_school ->
          update_existing_school_with_user(conn, existing_school, params)
      end
    end
  end

  defp create_school_and_user(conn, params) do
    with {:ok, %School{} = school} <- Schools.create_school_with_user(params) do
      conn
      |> put_status(:created)
      |> render(:show, school: school)
    end
  end

  defp update_existing_school_with_user(conn, existing_school, params) do
    user =
      case existing_school.user_id do
        nil ->
          {:ok, %User{} = user} = Users.create_user(params)
          user

        user_id ->
          Users.get_user!(user_id)
      end

    with {:ok, %School{} = school} <-
           Schools.update_school_with_user(existing_school, user, params),
         {:ok, _} <- update_users_for_school(school.id) do
      conn
      |> put_status(:ok)
      |> render(:show, school: school)
    end
  end

  defp update_users_for_school(school_id) do
    Util.update_users_for_group(school_id, "school")
  end
end
