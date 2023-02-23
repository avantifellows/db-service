defmodule DbserviceWeb.UserSessionController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.UserSession

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.UserSession, as: SwaggerSchemaUserSession

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaUserSession.user_session(),
      SwaggerSchemaUserSession.user_sessions()
    )
  end

  swagger_path :index do
    get("/api/user-session")
    response(200, "OK", Schema.ref(:UserSessions))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    user_session =
      Enum.reduce(param, UserSession, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", user_session: user_session)
  end

  swagger_path :create do
    post("/api/user-session")

    parameters do
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(201, "Created", Schema.ref(:UserSession))
  end

  def create(conn, %{"user_session" => user_session_params}) do
    with {:ok, %UserSession{} = user_session} <-
           Sessions.create_user_session(user_session_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.user_session_path(conn, :show, user_session)
      )
      |> render("show.json", user_session: user_session)
    end
  end

  swagger_path :show do
    get("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the user session", required: true)
    end

    response(200, "OK", Schema.ref(:UserSession))
  end

  def show(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)
    render(conn, "show.json", user_session: user_session)
  end

  swagger_path :update do
    patch("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the session", required: true)
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(200, "Updated", Schema.ref(:UserSession))
  end

  def update(conn, %{"id" => id, "user_session" => user_session_params}) do
    user_session = Sessions.get_user_session!(id)

    with {:ok, %UserSession{} = user_session} <-
           Sessions.update_user_session(user_session, user_session_params) do
      render(conn, "show.json", user_session: user_session)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the user session", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)

    with {:ok, %UserSession{}} <- Sessions.delete_user_session(user_session) do
      send_resp(conn, :no_content, "")
    end
  end
end
