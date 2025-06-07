defmodule DbserviceWeb.LearningObjectiveController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.LearningObjectives
  alias Dbservice.LearningObjectives.LearningObjective

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.LearningObjective, as: SwaggerSchemaLearningObjective

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaLearningObjective.learning_objective(),
      SwaggerSchemaLearningObjective.learning_objectives()
    )
  end

  swagger_path :index do
    get("/api/learning-objective")

    parameters do
      params(:query, :string, "The learning objective of a topic",
        required: false,
        name: "title"
      )
    end

    response(200, "OK", Schema.ref(:LearningObjectives))
  end

  def index(conn, params) do
    query =
      from(m in LearningObjective,
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

    learning_objective = Repo.all(query)

    json(
      conn,
      DbserviceWeb.LearningObjectiveJSON.index(%{learning_objective: learning_objective})
    )
  end

  swagger_path :create do
    post("/api/learning-objective")

    parameters do
      body(:body, Schema.ref(:LearningObjective), "Learning objective to create", required: true)
    end

    response(201, "Created", Schema.ref(:LearningObjective))
  end

  def create(conn, params) do
    with {:ok, %LearningObjective{} = learning_objective} <-
           LearningObjectives.create_learning_objective(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/learning-objective/#{learning_objective}"
      )
      |> json(DbserviceWeb.LearningObjectiveJSON.show(%{learning_objective: learning_objective}))
    end
  end

  swagger_path :show do
    get("/api/learning-objective/{learningObjectiveId}")

    parameters do
      learningObjectiveId(:path, :integer, "The id of the learning_objective record",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:LearningObjective))
  end

  def show(conn, %{"id" => id}) do
    learning_objective = LearningObjectives.get_learning_objective!(id)
    json(conn, DbserviceWeb.LearningObjectiveJSON.show(%{learning_objective: learning_objective}))
  end

  swagger_path :update do
    patch("/api/learning-objective/{learningObjectiveId}")

    parameters do
      learningObjectiveId(:path, :integer, "The id of the learning objective record",
        required: true
      )

      body(:body, Schema.ref(:LearningObjective), "LearningObjective to create", required: true)
    end

    response(200, "Updated", Schema.ref(:LearningObjective))
  end

  def update(conn, params) do
    learning_objective = LearningObjectives.get_learning_objective!(params["id"])

    with {:ok, %LearningObjective{} = learning_objective} <-
           LearningObjectives.update_learning_objective(learning_objective, params) do
      json(
        conn,
        DbserviceWeb.LearningObjectiveJSON.show(%{learning_objective: learning_objective})
      )
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/learning-objective/{learningObjectiveId}")

    parameters do
      learningObjectiveId(:path, :integer, "The id of the learning objective", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    learning_objective = LearningObjectives.get_learning_objective!(id)

    with {:ok, %LearningObjective{}} <-
           LearningObjectives.delete_learning_objective(learning_objective) do
      send_resp(conn, :no_content, "")
    end
  end
end
