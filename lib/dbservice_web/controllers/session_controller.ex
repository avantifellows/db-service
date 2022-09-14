defmodule DbserviceWeb.SessionController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Groups.GroupSession
  alias Dbservice.Sessions.Session

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Session, as: SwaggerSchemaSession

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      SwaggerSchemaSession.session(),
      SwaggerSchemaSession.sessions()
    )
  end

  swagger_path :index do
    get("/api/session")
    response(200, "OK", Schema.ref(:Sessions))
  end

  def index(conn, _params) do
    session = Sessions.list_session()
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
    get("/api/session/{sessionId}")

    parameters do
      sessionId(:path, :integer, "The id of the session", required: true)
    end

    response(200, "OK", Schema.ref(:Session))
  end

  def show(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)
    render(conn, "show.json", session: session)
  end

  swagger_path :update do
    patch("/api/session/{sessionId}")

    parameters do
      sessionId(:path, :integer, "The id of the session", required: true)
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
    PhoenixSwagger.Path.delete("/api/session/{sessionId}")

    parameters do
      sessionId(:path, :integer, "The id of the session", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)

    with {:ok, %Session{}} <- Sessions.delete_session(session) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_groups(conn, %{"session_id" => session_id, "group_id" => group_id})
      when is_list(group_id) do
    with {:ok, %GroupSession{} = session} <- Sessions.update_groups(session_id, group_id) do
      render(conn, "show.json", session: session)
    end
  end
end
