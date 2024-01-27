defmodule DbserviceWeb.GroupSessionController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.GroupSessions
  alias Dbservice.Groups.GroupSession

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  swagger_path :index do
    get("/api/group-session")

    parameters do
      params(:query, :integer, "The id the group type", required: false, name: "group_type_id")

      params(:query, :integer, "The id the session",
        required: false,
        name: "session_id"
      )
    end

    response(200, "OK", Schema.ref(:GroupSessions))
  end

  def index(conn, params) do
    query =
      from m in GroupSession,
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

    group_session = Repo.all(query)
    render(conn, "index.json", group_session: group_session)
  end

  swagger_path :create do
    post("/api/group-session")

    parameters do
      body(:body, Schema.ref(:GroupSessions), "Group session to create", required: true)
    end

    response(201, "Created", Schema.ref(:GroupSessions))
  end

  def create(conn, params) do
    case GroupSessions.get_group_session_by_session_id(params["session_id"]) do
      nil ->
        create_new_group_session(conn, params)

      existing_group_session ->
        update_existing_group_session(conn, existing_group_session, params)
    end
  end

  swagger_path :show do
    get("/api/group-session/{groupSessionId}")

    parameters do
      groupSessionId(:path, :integer, "The id of the group session record", required: true)
    end

    response(200, "OK", Schema.ref(:GroupSessions))
  end

  def show(conn, %{"id" => id}) do
    group_session = GroupSessions.get_group_session!(id)
    render(conn, "show.json", group_session: group_session)
  end

  swagger_path :update do
    patch("/api/group-session/{groupSessionId}")

    parameters do
      groupSessionId(:path, :integer, "The id of the session record", required: true)
      body(:body, Schema.ref(:GroupSessions), "Group session to create", required: true)
    end

    response(200, "Updated", Schema.ref(:GroupSessions))
  end

  def update(conn, params) do
    group_session = GroupSessions.get_group_session!(params["id"])

    with {:ok, %GroupSession{} = group_session} <-
           GroupSessions.update_group_session(group_session, params) do
      render(conn, "show.json", group_session: group_session)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/group-session/{groupSessionId}")

    parameters do
      groupSessionId(:path, :integer, "The id of the group session record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, params) do
    group_session = GroupSessions.get_group_session!(params["id"])

    with {:ok, %GroupSession{}} <- GroupSessions.delete_group_session(group_session) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_group_session(conn, params) do
    with {:ok, %GroupSession{} = group_session} <-
           GroupSessions.create_group_session(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.group_session_path(conn, :show, group_session)
      )
      |> render("show.json", group_session: group_session)
    end
  end

  defp update_existing_group_session(conn, existing_group_session, params) do
    with {:ok, %GroupSession{} = group_session} <-
           GroupSessions.update_group_session(existing_group_session, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", group_session: group_session)
    end
  end
end
