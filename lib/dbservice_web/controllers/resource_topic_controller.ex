defmodule DbserviceWeb.ResourceTopicController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ResourceTopics
  alias Dbservice.Resources.ResourceTopic

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource_topic(),
      SwaggerSchemaResource.resource_topics()
    )
  end

  swagger_path :index do
    get("/api/resource-topic")

    parameters do
      params(:query, :integer, "The id the resource", required: false, name: "resource_id")

      params(:query, :integer, "The id the topic",
        required: false,
        name: "topic_id"
      )
    end

    response(200, "OK", Schema.ref(:ResourceTopics))
  end

  def index(conn, params) do
    query =
      from(m in ResourceTopic,
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

    resource_topic = Repo.all(query)
    render(conn, "index.json", resource_topic: resource_topic)
  end

  swagger_path :create do
    post("/api/resource-topic")

    parameters do
      body(:body, Schema.ref(:ResourceTopic), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:ResourceTopic))
  end

  def create(conn, params) do
    case ResourceTopics.get_resource_topic_by_resource_id_and_topic_id(
           params["resource_id"],
           params["topic_id"]
         ) do
      nil ->
        create_new_resource_topic(conn, params)

      existing_resource_topic ->
        update_existing_resource_topic(conn, existing_resource_topic, params)
    end
  end

  swagger_path :show do
    get("/api/resource-topic/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceTopic))
  end

  def show(conn, %{"id" => id}) do
    resource_topic = ResourceTopics.get_resource_topic!(id)
    render(conn, "show.json", resource_topic: resource_topic)
  end

  swagger_path :update do
    patch("/api/resource-topic/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:ResourceTopic), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:ResourceTopic))
  end

  def update(conn, params) do
    resource_topic = ResourceTopics.get_resource_topic!(params["id"])

    with {:ok, %ResourceTopic{} = resource_topic} <-
           ResourceTopics.update_resource_topic(resource_topic, params) do
      render(conn, "show.json", resource_topic: resource_topic)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource-topic/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource_topic = ResourceTopics.get_resource_topic!(id)

    with {:ok, %ResourceTopic{}} <- ResourceTopics.delete_resource_topic(resource_topic) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource_topic(conn, params) do
    with {:ok, %ResourceTopic{} = resource_topic} <-
           ResourceTopics.create_resource_topic(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/resource-topic/#{resource_topic}")
      |> render("show.json", resource_topic: resource_topic)
    end
  end

  defp update_existing_resource_topic(conn, existing_resource_topic, params) do
    with {:ok, %ResourceTopic{} = resource_topic} <-
           ResourceTopics.update_resource_topic(existing_resource_topic, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource_topic: resource_topic)
    end
  end
end
