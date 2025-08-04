defmodule DbserviceWeb.SessionOccurrenceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.SessionOccurrence

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.SessionOccurrence, as: SwaggerSchemaSessionOccurrence

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        SwaggerSchemaSessionOccurrence.session_occurrence(),
        SwaggerSchemaSessionOccurrence.session_occurrences()
      ),
      SwaggerSchemaSessionOccurrence.session_occurrence_with_user()
    )
  end

  swagger_path :index do
    get("/api/session-occurrence")

    parameters do
      params(:query, :string, "The id the session",
        required: false,
        name: "session_id"
      )

      params(:query, :string, "Filter occurrences by time condition",
        required: false,
        name: "is_start_time",
        enum: ["today", "active"]
      )
    end

    response(200, "OK", Schema.ref(:SessionOccurrences))
  end

  def index(conn, params) do
    today = Date.utc_today()

    # Construct the beginning and end of today
    today_start = NaiveDateTime.new!(today, ~T[00:00:00])
    today_end = NaiveDateTime.new!(today, ~T[23:59:59])

    # Get current timestamp for active occurrence queries (when is_start_time="active")
    current_time = NaiveDateTime.utc_now() |> NaiveDateTime.add(5 * 3600 + 30 * 60, :second)

    session_ids_param = Map.get(params, "session_ids", "")
    session_ids = if session_ids_param != "", do: String.split(session_ids_param, ","), else: []

    query =
      from(m in SessionOccurrence,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset ->
            acc

          :limit ->
            acc

          :is_start_time ->
            apply_time_filter(acc, value, today_start, today_end, current_time)

          :session_ids ->
            from(u in acc, where: u.session_id in ^session_ids)

          atom ->
            from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    session_occurrence = Repo.all(query)
    render(conn, :index, session_occurrence: session_occurrence)
  end

  swagger_path :create do
    post("/api/session-occurrence")

    parameters do
      body(:body, Schema.ref(:SessionOccurrence), "Session occurence to create", required: true)
    end

    response(201, "Created", Schema.ref(:SessionOccurrence))
  end

  def create(conn, params) do
    with {:ok, %SessionOccurrence{} = session_occurrence} <-
           Sessions.create_session_occurrence(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/session-occurrence/#{session_occurrence}"
      )
      |> render(:show, session_occurrence: session_occurrence)
    end
  end

  swagger_path :show do
    get("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurence record",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:SessionOccurrenceWithUser))
  end

  def show(conn, %{"id" => id}) do
    session_occurrence = Sessions.get_session_occurrence!(id)
    render(conn, :show, session_occurrence: session_occurrence)
  end

  swagger_path :update do
    patch("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurrence", required: true)
      body(:body, Schema.ref(:SessionOccurrence), "Session occurrence to create", required: true)
    end

    response(200, "Updated", Schema.ref(:SessionOccurrence))
  end

  def update(conn, params) do
    session_occurrence = Sessions.get_session_occurrence!(params["id"])

    with {:ok, %SessionOccurrence{} = session_occurrence} <-
           Sessions.update_session_occurrence(session_occurrence, params) do
      render(conn, :show, session_occurrence: session_occurrence)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurence record",
        required: true
      )
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    session_occurrence = Sessions.get_session_occurrence!(id)

    with {:ok, %SessionOccurrence{}} <- Sessions.delete_session_occurrence(session_occurrence) do
      send_resp(conn, :no_content, "")
    end
  end

  defp apply_time_filter(query, value, today_start, today_end, current_time) do
    case value do
      "today" ->
        from(u in query, where: u.start_time >= ^today_start and u.start_time <= ^today_end)

      "active" ->
        from(u in query, where: u.start_time <= ^current_time and u.end_time >= ^current_time)

      _ ->
        query
    end
  end
end
