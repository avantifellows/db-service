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

    parameters do
      params(:query, :string, "The id the user",
        required: false,
        name: "user_id"
      )
    end

    response(200, "OK", Schema.ref(:UserSessions))
  end

  def index(conn, params) do
    query =
      from m in UserSession,
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

    user_session = Repo.all(query)
    render(conn, "index.json", user_session: user_session)
  end

  swagger_path :create do
    post("/api/user-session")

    parameters do
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(201, "Created", Schema.ref(:UserSession))
  end

  def create(conn, params) do
    with {:ok, %UserSession{} = user_session} <-
           Sessions.create_user_session(params) do
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
      userSessionId(:path, :integer, "The id of the user session record", required: true)
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
      userSessionId(:path, :integer, "The id of the session record", required: true)
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(200, "Updated", Schema.ref(:UserSession))
  end

  def update(conn, params) do
    user_session = Sessions.get_user_session!(params["id"])

    with {:ok, %UserSession{} = user_session} <-
           Sessions.update_user_session(user_session, params) do
      render(conn, "show.json", user_session: user_session)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the user session record", required: true)
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
