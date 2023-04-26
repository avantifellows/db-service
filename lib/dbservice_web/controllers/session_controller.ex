defmodule DbserviceWeb.SessionController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.Session

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Session, as: SwaggerSchemaSession
  alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        SwaggerSchemaSession.session(),
        SwaggerSchemaSession.sessions()
      ),
      SwaggerSchemaCommon.group_ids()
    )
  end

  swagger_path :index do
    get("/api/session?session_id=c714-e1d4-5a42-0f9f-36b3")
    response(200, "OK", Schema.ref(:Sessions))
  end

  def index(conn, params) do
    query =
      from m in Session,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    session = Repo.all(query)
    render(conn, "index.json", session: session)
  end

  swagger_path :create do
    post("/api/session")

    parameters do
      body(:body, Schema.ref(:Session), "Session to create", required: true)
    end

    response(201, "Created", Schema.ref(:Session))
  end

  def create(conn, params) do
    with {:ok, %Session{} = session} <- Sessions.create_session(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.session_path(conn, :show, session))
      |> render("show.json", session: session)
    end
  end

  swagger_path :show do
    get("/api/session/{id}")

    parameters do
      id(:path, :integer, "The id of the session record", required: true)
    end

    response(200, "OK", Schema.ref(:Session))
  end

  def show(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)
    render(conn, "show.json", session: session)
  end

  swagger_path :update do
    patch("/api/session/{id}")

    parameters do
      id(:path, :integer, "The id of the session record", required: true)
      body(:body, Schema.ref(:Session), "Session to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Session))
  end

  def update(conn, params) do
    session = Sessions.get_session!(params["id"])

    with {:ok, %Session{} = session} <- Sessions.update_session(session, params) do
      render(conn, "show.json", session: session)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/session/{id}")

    parameters do
      id(:path, :integer, "The id of the session record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)

    with {:ok, %Session{}} <- Sessions.delete_session(session) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :update_groups do
    post("/api/session/{id}/update-groups")

    parameters do
      id(:path, :integer, "The id of the session record", required: true)

      body(:body, Schema.ref(:GroupIds), "List of group ids to update for the session",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:Session))
  end

  def update_groups(conn, %{"id" => session_id, "group_ids" => group_ids})
      when is_list(group_ids) do
    with {:ok, %Session{} = session} <- Sessions.update_groups(session_id, group_ids) do
      render(conn, "show.json", session: session)
    end
  end
end
