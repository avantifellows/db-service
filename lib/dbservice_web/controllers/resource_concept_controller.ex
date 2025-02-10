defmodule DbserviceWeb.ResourceConceptController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ResourceConcepts
  alias Dbservice.Resources.ResourceConcept

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource_concept(),
      SwaggerSchemaResource.resource_concepts()
    )
  end

  swagger_path :index do
    get("/api/resource-concept")

    parameters do
      params(:query, :integer, "The id the resource", required: false, name: "resource_id")

      params(:query, :integer, "The id the concept",
        required: false,
        name: "concept_id"
      )
    end

    response(200, "OK", Schema.ref(:ResourceConcepts))
  end

  def index(conn, params) do
    query =
      from(m in ResourceConcept,
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

    resource_concept = Repo.all(query)
    render(conn, "index.json", resource_concept: resource_concept)
  end

  swagger_path :create do
    post("/api/resource-concept")

    parameters do
      body(:body, Schema.ref(:ResourceConcept), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:ResourceConcept))
  end

  def create(conn, params) do
    case ResourceConcepts.get_resource_concept_by_resource_concept_id(
           params["resource_id"],
           params["concept_id"]
         ) do
      nil ->
        create_new_resource_concept(conn, params)

      existing_resource_concept ->
        update_existing_resource_concept(conn, existing_resource_concept, params)
    end
  end

  swagger_path :show do
    get("/api/resource-concept/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceConcept))
  end

  def show(conn, %{"id" => id}) do
    resource_concept = ResourceConcepts.get_resource_concept!(id)
    render(conn, "show.json", resource_concept: resource_concept)
  end

  swagger_path :update do
    patch("/api/resource-concept/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:ResourceConcept), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:ResourceConcept))
  end

  def update(conn, params) do
    resource_concept = ResourceConcepts.get_resource_concept!(params["id"])

    with {:ok, %ResourceConcept{} = resource_concept} <-
           ResourceConcepts.update_resource_concept(resource_concept, params) do
      render(conn, "show.json", resource_concept: resource_concept)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource-concept/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource_concept = ResourceConcepts.get_resource_concept!(id)

    with {:ok, %ResourceConcept{}} <- ResourceConcepts.delete_resource_concept(resource_concept) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource_concept(conn, params) do
    with {:ok, %ResourceConcept{} = resource_concept} <-
           ResourceConcepts.create_resource_concept(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.resource_concept_path(conn, :show, resource_concept))
      |> render("show.json", resource_concept: resource_concept)
    end
  end

  defp update_existing_resource_concept(conn, existing_resource_concept, params) do
    with {:ok, %ResourceConcept{} = resource_concept} <-
           ResourceConcepts.update_resource_concept(existing_resource_concept, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource_concept: resource_concept)
    end
  end
end
