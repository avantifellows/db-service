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
        Map.merge(
          SwaggerSchemaSession.session(),
          SwaggerSchemaSession.sessions()
        ),
        SwaggerSchemaSession.session_search()
      ),
      SwaggerSchemaCommon.group_ids()
    )
  end

  swagger_path :index do
    get("/api/session")

    parameters do
      params(:query, :string, "The id the session",
        required: false,
        name: "session_id"
      )

      params(:query, :string, "The name the session", required: false, name: "name")

      params(:query, :string, "The platform id the session", required: false, name: "platform_id")
    end

    response(200, "OK", Schema.ref(:Sessions))
  end

  def index(conn, params) do
    sort_order = extract_sort_order(params)

    query =
      from m in Session,
        order_by: [{^sort_order, m.id}],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset ->
            acc

          :limit ->
            acc

          :sort_order ->
            acc

          :session_id_is_null ->
            apply_session_id_null_filter(value, acc)

          :is_quiz ->
            apply_is_quiz_filter(value, acc)

          atom ->
            apply_filter_based_on_schema(atom, key, value, acc)
        end
      end)

    session = Repo.all(query)
    render(conn, :index, session: session)
  end

  defp apply_filter_based_on_schema(atom, key, value, acc) do
    if atom in Session.__schema__(:fields) do
      from(u in acc, where: field(u, ^atom) == ^value)
    else
      from u in acc,
        where: fragment("?->>? = ?", u.meta_data, ^key, ^value)
    end
  end

  defp extract_sort_order(params) do
    case params["sort_order"] do
      "asc" -> :asc
      _ -> :desc
    end
  end

  defp apply_session_id_null_filter(value, acc) do
    case value do
      "true" -> from u in acc, where: is_nil(u.session_id)
      "false" -> from u in acc, where: not is_nil(u.session_id)
      _ -> acc
    end
  end

  defp apply_is_quiz_filter(value, acc) do
    case value do
      "true" -> from u in acc, where: u.platform == "quiz"
      "false" -> from u in acc, where: u.platform != "quiz" or is_nil(u.platform)
      _ -> acc
    end
  end

  swagger_path :create do
    post("/api/session")

    parameters do
      body(:body, Schema.ref(:Session), "Session to create", required: true)
    end

    response(201, "Created", Schema.ref(:Session))
  end

  def create(conn, params) do
    session_id = params["session_id"]

    if is_nil(session_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Session ID is required"})
    else
      case Sessions.get_session_by_session_id(session_id) do
        nil ->
          create_new_session(conn, params)

        existing_session ->
          update_existing_session(conn, existing_session, params)
      end
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
    render(conn, :show, session: session)
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
      render(conn, :show, session: session)
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
      render(conn, :show, session: session)
    end
  end

  swagger_path :search do
    post("/api/session/search")
    summary("Bulk search sessions by platform IDs")
    description("Search for multiple sessions by providing a list of platform_ids")

    parameters do
      body(:body, Schema.ref(:SessionSearch), "Search parameters", required: true)
    end

    response(200, "OK", Schema.ref(:Sessions))
  end

  def search(conn, params) do
    platform_ids = Map.get(params, "platform_ids", [])
    platform = Map.get(params, "platform")

    query = build_search_query(platform_ids, platform, params)
    sessions = Repo.all(query)

    render(conn, :index, session: sessions)
  end

  defp build_search_query(platform_ids, platform, params) do
    sort_order = extract_sort_order(params)

    base_query =
      from m in Session,
        order_by: [{^sort_order, m.id}],
        offset: ^params["offset"],
        limit: ^params["limit"]

    # Apply platform_ids filter if provided
    base_query =
      if platform_ids != [] do
        from(s in base_query, where: s.platform_id in ^platform_ids)
      else
        base_query
      end

    # Apply platform filter if provided
    if platform do
      from(s in base_query, where: s.platform == ^platform)
    else
      base_query
    end
  end

  defp create_new_session(conn, params) do
    with {:ok, %Session{} = session} <- Sessions.create_session(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/session/#{session}")
      |> render(:show, session: session)
    end
  end

  defp update_existing_session(conn, existing_session, params) do
    with {:ok, %Session{} = session} <- Sessions.update_session(existing_session, params) do
      conn
      |> put_status(:ok)
      |> render(:show, session: session)
    end
  end
end
