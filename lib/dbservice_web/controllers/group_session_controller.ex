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
    response(200, "OK", Schema.ref(:GroupSessions))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    group_session =
      Enum.reduce(param, GroupSession, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

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

  swagger_path :show do
    get("/api/group-session/{groupSessionId}")

    parameters do
      groupSessionId(:path, :integer, "The id of the group session", required: true)
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
      groupSessionId(:path, :integer, "The id of the session", required: true)
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
      groupSessionId(:path, :integer, "The id of the group session", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, params) do
    group_session = GroupSessions.get_group_session!(params["id"])

    with {:ok, %GroupSession{}} <- GroupSessions.delete_group_session(group_session) do
      send_resp(conn, :no_content, "")
    end
  end
end
