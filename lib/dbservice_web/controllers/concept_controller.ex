defmodule DbserviceWeb.ConceptController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Concepts
  alias Dbservice.Concepts.Concept

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Concept, as: SwaggerSchemaConcept

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaConcept.concept(),
      SwaggerSchemaConcept.concepts()
    )
  end

  swagger_path :index do
    get("/api/concept")

    parameters do
      params(:query, :string, "The concept of a topic",
        required: false,
        name: "name"
      )
    end

    response(200, "OK", Schema.ref(:Concepts))
  end

  def index(conn, params) do
    query =
      from(m in Concept,
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

    concept = Repo.all(query)
    render(conn, :index, concept: concept)
  end

  swagger_path :create do
    post("/api/concept")

    parameters do
      body(:body, Schema.ref(:Concept), "Concept to create", required: true)
    end

    response(201, "Created", Schema.ref(:Concept))
  end

  def create(conn, params) do
    with {:ok, %Concept{} = concept} <- Concepts.create_concept(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/concept/#{concept}")
      |> render(:show, concept: concept)
    end
  end

  swagger_path :show do
    get("/api/concept/{conceptId}")

    parameters do
      conceptId(:path, :integer, "The id of the concept record", required: true)
    end

    response(200, "OK", Schema.ref(:Concept))
  end

  def show(conn, %{"id" => id}) do
    concept = Concepts.get_concept!(id)
    render(conn, :show, concept: concept)
  end

  swagger_path :update do
    patch("/api/concept/{conceptId}")

    parameters do
      conceptId(:path, :integer, "The id of the concept record", required: true)
      body(:body, Schema.ref(:Concept), "Concept to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Concept))
  end

  def update(conn, params) do
    concept = Concepts.get_concept!(params["id"])

    with {:ok, %Concept{} = concept} <- Concepts.update_concept(concept, params) do
      render(conn, :show, concept: concept)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/concept/{conceptId}")

    parameters do
      conceptId(:path, :integer, "The id of the concept record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    concept = Concepts.get_concept!(id)

    with {:ok, %Concept{}} <- Concepts.delete_concept(concept) do
      send_resp(conn, :no_content, "")
    end
  end
end
