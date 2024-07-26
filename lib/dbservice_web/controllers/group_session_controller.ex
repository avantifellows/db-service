defmodule DbserviceWeb.GroupSessionController do
  alias Dbservice.AuthGroups
  alias Dbservice.Batches
  alias Dbservice.Groups
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
      params(:query, :integer, "The id the group", required: false, name: "group_id")

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

  swagger_path :get_auth_group_from_session do
    get("/api/group-session/session-auth-group")
    description("Fetches the associated auth group data for a session")

    parameters do
      session_id(:query, :integer, "The ID of the session", required: true)
    end

    response(200, "Success", Schema.ref(:AuthGroup))
  end

  def get_auth_group_from_session(conn, %{"session_id" => session_id}) do
    with {:ok, group_sessions} <- get_group_sessions(session_id),
         {:ok, group} <- get_group(group_sessions),
         {:ok, batch} <- get_batch(group.child_id),
         {:ok, auth_group} <- get_auth_group(batch.auth_group_id) do
      conn
      |> put_status(:ok)
      |> put_view(DbserviceWeb.AuthGroupView)
      |> render("auth_group.json", auth_group: auth_group)
    else
      {:error, :not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: message})

      {:error, :bad_request, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp get_group_sessions(session_id) do
    case GroupSessions.get_all_group_sessions_by_session_id(session_id) do
      [] -> {:error, :not_found, "Group sessions not found"}
      group_sessions -> {:ok, group_sessions}
    end
  end

  defp get_group(group_sessions) do
    batch_group =
      Enum.find_value(group_sessions, fn group_session ->
        case Groups.get_group!(group_session.group_id) do
          %{type: "batch"} = group -> group
          _ -> nil
        end
      end)

    case batch_group do
      nil -> {:error, :not_found, "Batch group not found"}
      group -> {:ok, group}
    end
  end

  defp get_batch(batch_id) do
    case Batches.get_batch!(batch_id) do
      nil -> {:error, :not_found, "Batch not found"}
      batch -> {:ok, batch}
    end
  end

  defp get_auth_group(auth_group_id) do
    case AuthGroups.get_auth_group!(auth_group_id) do
      nil -> {:error, :not_found, "Auth group not found"}
      auth_group -> {:ok, auth_group}
    end
  end
end
