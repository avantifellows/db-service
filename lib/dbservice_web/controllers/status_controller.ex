defmodule DbserviceWeb.StatusController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Statuses
  alias Dbservice.Statuses.Status

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Status, as: SwaggerSchemaStatus

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaStatus.status(),
      SwaggerSchemaStatus.statuses()
    )
  end

  swagger_path :index do
    get("/api/status")

    parameters do
      params(:query, :string, "The title of status",
        required: false,
        title: "title"
      )
    end

    response(200, "OK", Schema.ref(:Statuses))
  end

  def index(conn, params) do
    query =
      from(m in Status,
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

    status = Repo.all(query)
    render(conn, :index, status: status)
  end

  swagger_path :create do
    post("/api/status")

    parameters do
      body(:body, Schema.ref(:Status), "Status to create", required: true)
    end

    response(201, "Created", Schema.ref(:Status))
  end

  def create(conn, params) do
    with {:ok, %Status{} = status} <- Statuses.create_status(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/status/#{status}")
      |> render(:show, status: status)
    end
  end

  swagger_path :show do
    get("/api/status/{statusId}")

    parameters do
      statusId(:path, :integer, "The id of the status record", required: true)
    end

    response(200, "OK", Schema.ref(:Status))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    status = Statuses.get_status!(id)
    render(conn, :show, status: status)
  end

  swagger_path :update do
    patch("/api/status/{statusId}")

    parameters do
      statusId(:path, :integer, "The id of the status record", required: true)
      body(:body, Schema.ref(:Status), "Status to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Status))
  end

  def update(conn, params) do
    status = Statuses.get_status!(params["id"])

    with {:ok, %Status{} = status} <- Statuses.update_status(status, params) do
      render(conn, :show, status: status)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/status/{statusId}")

    parameters do
      statusId(:path, :integer, "The id of the status record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    status = Statuses.get_status!(id)

    with {:ok, %Status{}} <- Statuses.delete_status(status) do
      send_resp(conn, :no_content, "")
    end
  end
end
