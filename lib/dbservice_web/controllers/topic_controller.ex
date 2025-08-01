defmodule DbserviceWeb.TopicController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Topics
  alias Dbservice.Topics.Topic
  alias Dbservice.Utils.Util

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Topic, as: SwaggerSchemaTopic

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaTopic.topic(),
      SwaggerSchemaTopic.topics()
    )
  end

  swagger_path :index do
    get("/api/topic")

    parameters do
      params(:query, :string, "The topic of a chapter",
        required: false,
        name: "name"
      )

      params(:query, :string, "The code of the topic",
        required: false,
        name: "code"
      )
    end

    response(200, "OK", Schema.ref(:Topics))
  end

  def index(conn, params) do
    query =
      from(m in Topic,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    # |> Ecto.Query.preload(:tag)

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset ->
            acc

          :limit ->
            acc

          :lang_code ->
            acc

          :name ->
            from(u in acc,
              where:
                fragment(
                  "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'topic' = ?)",
                  u.name,
                  ^value
                )
            )

          atom ->
            from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    # Language filtering
    query = Util.filter_by_lang(query, params)

    topic = Repo.all(query)
    render(conn, :index, topic: topic)
  end

  swagger_path :create do
    post("/api/topic")

    parameters do
      body(:body, Schema.ref(:Topic), "Topic to create", required: true)
    end

    response(201, "Created", Schema.ref(:Topic))
  end

  def create(conn, params) do
    case Topics.get_topic_by_code(params["code"]) do
      nil ->
        create_new_topic(conn, params)

      existing_topic ->
        update_existing_topic(conn, existing_topic, params)
    end
  end

  swagger_path :show do
    get("/api/topic/{topicId}")

    parameters do
      topicId(:path, :integer, "The id of the topic record", required: true)
    end

    response(200, "OK", Schema.ref(:Topic))
  end

  def show(conn, %{"id" => id}) do
    topic = Topics.get_topic!(id)
    render(conn, :show, topic: topic)
  end

  swagger_path :update do
    patch("/api/topic/{topicId}")

    parameters do
      topicId(:path, :integer, "The id of the topic record", required: true)
      body(:body, Schema.ref(:Topic), "Topic to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Topic))
  end

  def update(conn, params) do
    topic = Topics.get_topic!(params["id"])

    with {:ok, %Topic{} = topic} <- Topics.update_topic(topic, params) do
      render(conn, :show, topic: topic)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/topic/{topicId}")

    parameters do
      topicId(:path, :integer, "The id of the topic record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    topic = Topics.get_topic!(id)

    with {:ok, %Topic{}} <- Topics.delete_topic(topic) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_topic(conn, params) do
    with {:ok, %Topic{} = topic} <- Topics.create_topic_with_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/topic/#{topic}")
      |> render(:show, topic: topic)
    end
  end

  defp update_existing_topic(conn, existing_topic, params) do
    with {:ok, %Topic{} = topic} <-
           Topics.update_topic_with_curriculum(existing_topic, params) do
      conn
      |> put_status(:ok)
      |> render(:show, topic: topic)
    end
  end
end
