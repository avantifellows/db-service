defmodule DbserviceWeb.TopicCurriculumController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.TopicCurriculums.TopicCurriculum
  alias Dbservice.TopicCurriculums

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.TopicCurriculum, as: SwaggerSchemaTopicCurriculum

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaTopicCurriculum.topic_curriculum(),
      SwaggerSchemaTopicCurriculum.topic_curriculums()
    )
  end

  swagger_path :index do
    get("/api/topic-curriculum")

    parameters do
      params(:query, :integer, "The id of the topic", required: false, name: "topic_id")
      params(:query, :integer, "The id of the curriculum", required: false, name: "curriculum_id")
    end

    response(200, "OK", Schema.ref(:TopicCurriculum))
  end

  def index(conn, params) do
    query =
      from(cc in TopicCurriculum,
        order_by: [asc: cc.id],
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

    topic_curriculum = Repo.all(query)
    render(conn, "index.json", topic_curriculum: topic_curriculum)
  end

  swagger_path :create do
    post("/api/topic-curriculum")

    parameters do
      body(:body, Schema.ref(:TopicCurriculum), "Topic curriculum to create", required: true)
    end

    response(201, "Created", Schema.ref(:TopicCurriculum))
  end

  def create(conn, params) do
    case TopicCurriculums.get_topic_curriculum_by_topic_id_and_curriculum_id(
           params["topic_id"],
           params["curriculum_id"]
         ) do
      nil ->
        create_new_topic_curriculum(conn, params)

      existing_topic_curriculum ->
        update_existing_topic_curriculum(conn, existing_topic_curriculum, params)
    end
  end

  swagger_path :show do
    get("/api/topic-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the topic curriculum record", required: true)
    end

    response(200, "OK", Schema.ref(:TopicCurriculum))
  end

  def show(conn, %{"id" => id}) do
    topic_curriculum = TopicCurriculums.get_topic_curriculum!(id)
    render(conn, "show.json", topic_curriculum: topic_curriculum)
  end

  swagger_path :update do
    patch("/api/topic-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the topic curriculum", required: true)
      body(:body, Schema.ref(:TopicCurriculum), "Topic curriculum to update", required: true)
    end

    response(200, "Updated", Schema.ref(:TopicCurriculum))
  end

  def update(conn, params) do
    topic_curriculum = TopicCurriculums.get_topic_curriculum!(params["id"])

    with {:ok, %TopicCurriculum{} = topic_curriculum} <-
           TopicCurriculums.update_topic_curriculum(topic_curriculum, params) do
      render(conn, "show.json", topic_curriculum: topic_curriculum)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/topic-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the topic curriculum record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    topic_curriculum = TopicCurriculums.get_topic_curriculum!(id)

    with {:ok, %TopicCurriculum{}} <-
           TopicCurriculums.delete_topic_curriculum(topic_curriculum) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_topic_curriculum(conn, params) do
    with {:ok, %TopicCurriculum{} = topic_curriculum} <-
           TopicCurriculums.create_topic_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/topic-curriculum/#{topic_curriculum}"
      )
      |> render("show.json", topic_curriculum: topic_curriculum)
    end
  end

  defp update_existing_topic_curriculum(conn, existing_topic_curriculum, params) do
    with {:ok, %TopicCurriculum{} = topic_curriculum} <-
           TopicCurriculums.update_topic_curriculum(existing_topic_curriculum, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", topic_curriculum: topic_curriculum)
    end
  end
end
