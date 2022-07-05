defmodule DbserviceWeb.SessionOccurenceController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Sessions.SessionOccurence

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      SessionOccurence:
        swagger_schema do
          title("SessionOccurence")
          description("A session occurence for a session")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurence start time")
            end_time(:timestamp, "Session occurence finish time")
          end

          example(%{
            session_id: 1,
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z"
          })
        end,
      SessionOccurenceWithUser:
        swagger_schema do
          title("SessionOccurenceWithUser")
          description("A single session occurence with user details")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurence start time")
            end_time(:timestamp, "Session occurence finish time")
            # TODO: users(Schema.ref(:Users), "Users for the session occurence")
          end

          example(%{
            session_id: 1,
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z"
            # TODO: users: [Schema.ref(:Users).items]
          })
        end,
      SessionOccurences:
        swagger_schema do
          title("SessionOccurences")
          description("All the session occurences ")
          type(:array)
          items(Schema.ref(:SessionOccurence))
        end
    }
  end

  swagger_path :index do
    get("/api/session-occurence")
    response(200, "OK", Schema.ref(:SessionOccurences))
  end

  def index(conn, _params) do
    session_occurence = Sessions.list_session_occurence()
    render(conn, "index.json", session_occurence: session_occurence)
  end

  swagger_path :create do
    post("/api/session-occurence")

    parameters do
      body(:body, Schema.ref(:SessionOccurence), "Session occurence to create", required: true)
    end

    response(201, "Created", Schema.ref(:SessionOccurence))
  end

  def create(conn, params) do
    with {:ok, %SessionOccurence{} = session_occurence} <-
           Sessions.create_session_occurence(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.session_occurence_path(conn, :show, session_occurence)
      )
      |> render("show.json", session_occurence: session_occurence)
    end
  end

  swagger_path :show do
    get("/api/session-occurence/{sessionOccurenceId}")

    parameters do
      sessionOccurenceId(:path, :integer, "The id of the session occurence", required: true)
    end

    response(200, "OK", Schema.ref(:SessionOccurenceWithUser))
  end

  def show(conn, %{"id" => id}) do
    session_occurence = Sessions.get_session_occurence!(id)
    render(conn, "show.json", session_occurence: session_occurence)
  end

  swagger_path :update do
    patch("/api/session-occurence/{sessionOccurenceId}")

    parameters do
      sessionOccurenceId(:path, :integer, "The id of the session occurence", required: true)
      body(:body, Schema.ref(:SessionOccurence), "Session occurence to create", required: true)
    end

    response(200, "Updated", Schema.ref(:SessionOccurence))
  end

  def update(conn, params) do
    session_occurence = Sessions.get_session_occurence!(params["id"])

    with {:ok, %SessionOccurence{} = session_occurence} <-
           Sessions.update_session_occurence(session_occurence, params) do
      render(conn, "show.json", session_occurence: session_occurence)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/session-occurence/{sessionOccurenceId}")

    parameters do
      sessionOccurenceId(:path, :integer, "The id of the session occurence", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    session_occurence = Sessions.get_session_occurence!(id)

    with {:ok, %SessionOccurence{}} <- Sessions.delete_session_occurence(session_occurence) do
      send_resp(conn, :no_content, "")
    end
  end
end
