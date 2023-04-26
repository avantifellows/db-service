defmodule DbserviceWeb.SchoolController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Schools.School

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
    get("/api/school?board_medium=en")
    response(200, "OK", Schema.ref(:Schools))
  end

  def index(conn, %{"code" => code}) do
    school = Repo.all(from t in School, where: t.code == ^code, select: t, limit: 1)
    render(conn, "index.json", school: school)
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
    render(conn, "index.json", school: school)
  end

  swagger_path :create do
    post("/api/school")

    parameters do
      body(:body, Schema.ref(:School), "School to create", required: true)
    end

    response(201, "Created", Schema.ref(:School))
  end

  def create(conn, params) do
    with {:ok, %School{} = school} <- Schools.create_school(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.school_path(conn, :show, school))
      |> render("show.json", school: school)
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
    render(conn, "show.json", school: school)
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
      render(conn, "show.json", school: school)
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
end
