defmodule DbserviceWeb.SourceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sources
  alias Dbservice.Sources.Source

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Source, as: SwaggerSchemaSource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaSource.source(),
      SwaggerSchemaSource.sources()
    )
  end

  swagger_path :index do
    get("/api/source")

    parameters do
      params(:query, :string, "The source of the content",
        required: false,
        name: "name"
      )

      params(:query, :string, "The link of the source",
        required: false,
        name: "link"
      )
    end

    response(200, "OK", Schema.ref(:Sources))
  end

  def index(conn, params) do
    query =
      from(m in Source,
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

    source = Repo.all(query)
    render(conn, :index, source: source)
  end

  swagger_path :create do
    post("/api/source")

    parameters do
      body(:body, Schema.ref(:Source), "Source to create", required: true)
    end

    response(201, "Created", Schema.ref(:Source))
  end

  def create(conn, params) do
    case Sources.get_source_by_link(params["link"]) do
      nil ->
        create_new_source(conn, params)

      existing_source ->
        update_existing_source(conn, existing_source, params)
    end
  end

  swagger_path :show do
    get("/api/source/{sourceId}")

    parameters do
      sourceId(:path, :integer, "The id of the source record", required: true)
    end

    response(200, "OK", Schema.ref(:Source))
  end

  def show(conn, %{"id" => id}) do
    source = Sources.get_source!(id)
    render(conn, :show, source: source)
  end

  swagger_path :update do
    patch("/api/source/{sourceId}")

    parameters do
      sourceId(:path, :integer, "The id of the source record", required: true)
      body(:body, Schema.ref(:Source), "Source to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Source))
  end

  def update(conn, params) do
    source = Sources.get_source!(params["id"])

    with {:ok, %Source{} = source} <- Sources.update_source(source, params) do
      render(conn, :show, source: source)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/source/{sourceId}")

    parameters do
      sourceId(:path, :integer, "The id of the source record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    source = Sources.get_source!(id)

    with {:ok, %Source{}} <- Sources.delete_source(source) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_source(conn, params) do
    with {:ok, %Source{} = source} <- Sources.create_source(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/source/#{source}")
      |> render(:show, source: source)
    end
  end

  defp update_existing_source(conn, existing_source, params) do
    with {:ok, %Source{} = source} <-
           Sources.update_source(existing_source, params) do
      conn
      |> put_status(:ok)
      |> render(:show, source: source)
    end
  end
end
