defmodule DbserviceWeb.UserSessionController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Sessions.UserSession

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      UserSession:
        swagger_schema do
          title("UserSession")
          description("A mapping between user and sesssion-occurence")

          properties do
            start_time(:timestamp, "User session start time")
            end_time(:timestamp, "User session end time")
            data(:map, "Additional data for user session")
            user_id(:integer, "The id of the user")
            session_occurence_id(:integer, "The id of the session occurence")
          end

          example(%{
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z",
            data: %{
              "substitute-teacher-name" => "Ms. Poonam"
            },
            user_id: 1,
            session_occurence_id: 2
          })
        end,
      UserSessions:
        swagger_schema do
          title("UserSessions")
          description("All user and session occurence mappings")
          type(:array)
          items(Schema.ref(:UserSession))
        end
    }
  end

  swagger_path :index do
    get("/api/user-session")
    response(200, "OK", Schema.ref(:UserSessions))
  end

  def index(conn, _params) do
    user_session = Sessions.list_user_session()
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
