defmodule DbserviceWeb.ResourceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Resources
  alias Dbservice.Resources.Resource

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource(),
      SwaggerSchemaResource.resources()
    )
  end

  swagger_path :index do
    get("/api/resource")

    parameters do
      params(:query, :string, "The resource of the content",
        required: false,
        name: "name"
      )
    end

    response(200, "OK", Schema.ref(:Resources))
  end

  def index(conn, params) do
    query =
      from(m in Resource,
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

    resource = Repo.all(query)
    render(conn, "index.json", resource: resource)
  end

  swagger_path :create do
    post("/api/resource")

    parameters do
      body(:body, Schema.ref(:Resource), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:Resource))
  end

  def create(conn, params) do
    case Resources.get_resource_by_name_and_source_id(params["name"], params["source_id"]) do
      nil ->
        create_new_resource(conn, params)

      existing_resource ->
        update_existing_resource(conn, existing_resource, params)
    end
  end

  swagger_path :show do
    get("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:Resource))
  end

  def show(conn, %{"id" => id}) do
    resource = Resources.get_resource!(id)
    render(conn, "show.json", resource: resource)
  end

  swagger_path :update do
    patch("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:Resource), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Resource))
  end

  def update(conn, params) do
    resource = Resources.get_resource!(params["id"])

    with {:ok, %Resource{} = resource} <- Resources.update_resource(resource, params) do
      render(conn, "show.json", resource: resource)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource = Resources.get_resource!(id)

    with {:ok, %Resource{}} <- Resources.delete_resource(resource) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource(conn, params) do
    with {:ok, %Resource{} = resource} <- Resources.create_resource(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.resource_path(conn, :show, resource))
      |> render("show.json", resource: resource)
    end
  end

  defp update_existing_resource(conn, existing_resource, params) do
    merged_params = merge_tag_ids(existing_resource, params)

    with {:ok, %Resource{} = resource} <-
           Resources.update_resource(existing_resource, merged_params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource: resource)
    end
  end

  defp merge_tag_ids(existing_resource, params) do
    existing_tags = existing_resource.tag_ids || []
    new_tags = Map.get(params, "tag_ids", [])

    # Ensure unique tags, cast to integers if necessary
    merged_tags =
      (existing_tags ++ new_tags)
      # Normalize to integers
      |> Enum.map(&String.to_integer(to_string(&1)))
      |> Enum.uniq()

    Map.put(params, "tag_ids", merged_tags)
  end
end
