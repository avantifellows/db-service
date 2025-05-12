defmodule DbserviceWeb.ResourceCurriculumController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ResourceCurriculums
  alias Dbservice.Resources.ResourceCurriculum

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource_curriculum(),
      SwaggerSchemaResource.resource_curriculums()
    )
  end

  swagger_path :index do
    get("/api/resource-curriculum")

    parameters do
      params(:query, :integer, "The id the resource", required: false, name: "resource_id")

      params(:query, :integer, "The id the curriculum",
        required: false,
        name: "curriculum_id"
      )
    end

    response(200, "OK", Schema.ref(:ResourceCurriculums))
  end

  def index(conn, params) do
    query =
      from(m in ResourceCurriculum,
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

    resource_curriculum = Repo.all(query)
    render(conn, "index.json", resource_curriculum: resource_curriculum)
  end

  swagger_path :create do
    post("/api/resource-curriculum")

    parameters do
      body(:body, Schema.ref(:ResourceCurriculum), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:ResourceCurriculum))
  end

  def create(conn, params) do
    case ResourceCurriculums.get_resource_curriculum_by_resource_id_and_curriculum_id(
           params["resource_id"],
           params["curriculum_id"]
         ) do
      nil ->
        create_new_resource_curriculum(conn, params)

      existing_resource_curriculum ->
        update_existing_resource_curriculum(conn, existing_resource_curriculum, params)
    end
  end

  swagger_path :show do
    get("/api/resource-curriculum/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceCurriculum))
  end

  def show(conn, %{"id" => id}) do
    resource_curriculum = ResourceCurriculums.get_resource_curriculum!(id)
    render(conn, "show.json", resource_curriculum: resource_curriculum)
  end

  swagger_path :update do
    patch("/api/resource-curriculum/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:ResourceCurriculum), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:ResourceCurriculum))
  end

  def update(conn, params) do
    resource_curriculum = ResourceCurriculums.get_resource_curriculum!(params["id"])

    with {:ok, %ResourceCurriculum{} = resource_curriculum} <-
           ResourceCurriculums.update_resource_curriculum(resource_curriculum, params) do
      render(conn, "show.json", resource_curriculum: resource_curriculum)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource-curriculum/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource_curriculum = ResourceCurriculums.get_resource_curriculum!(id)

    with {:ok, %ResourceCurriculum{}} <-
           ResourceCurriculums.delete_resource_curriculum(resource_curriculum) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource_curriculum(conn, params) do
    with {:ok, %ResourceCurriculum{} = resource_curriculum} <-
           ResourceCurriculums.create_resource_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.resource_curriculum_path(conn, :show, resource_curriculum)
      )
      |> render("show.json", resource_curriculum: resource_curriculum)
    end
  end

  defp update_existing_resource_curriculum(conn, existing_resource_curriculum, params) do
    with {:ok, %ResourceCurriculum{} = resource_curriculum} <-
           ResourceCurriculums.update_resource_curriculum(existing_resource_curriculum, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource_curriculum: resource_curriculum)
    end
  end
end
