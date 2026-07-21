defmodule DbserviceWeb.SessionOccurrenceController do
  use DbserviceWeb, :controller

  alias Dbservice.Utils.Pagination

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.SessionOccurrence
  alias Dbservice.Utils.Util

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

      params(
        :query,
        :string,
        "Only occurrences starting at or before this ISO-8601 timestamp",
        required: false,
        name: "start_time_lte"
      )

      params(
        :query,
        :string,
        "Only occurrences ending at or after this ISO-8601 timestamp",
        required: false,
        name: "end_time_gte"
      )
    end

    response(200, "OK", Schema.ref(:SessionOccurrences))
  end

  def index(conn, params) do
    session_ids = Map.get(params, "session_ids", [])

    case fetch_filtered_session_occurrences(session_ids, params) do
      {:ok, session_occurrences} ->
        render(conn, :index, session_occurrence: session_occurrences)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  def search(conn, params) do
    session_ids = Map.get(params, "session_ids", [])

    case fetch_filtered_session_occurrences(session_ids, params) do
      {:ok, session_occurrences} ->
        render(conn, :index, session_occurrence: session_occurrences)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp fetch_filtered_session_occurrences(session_ids, params) do
    today = Date.utc_today()

    # Construct the beginning and end of today
    today_start = NaiveDateTime.new!(today, ~T[00:00:00])
    today_end = NaiveDateTime.new!(today, ~T[23:59:59])

    # Get current timestamp for active occurrence queries (when is_start_time="active")
    current_time = NaiveDateTime.utc_now() |> NaiveDateTime.add(5 * 3600 + 30 * 60, :second)

    base_query =
      from(m in SessionOccurrence,
        order_by: [asc: m.id],
        offset: ^Pagination.offset(params),
        limit: ^Pagination.limit(params)
      )

    params
    |> Enum.reduce_while({:ok, base_query}, fn
      {"start_time_lte", value}, {:ok, acc} ->
        apply_window_filter(:start_time_lte, value, acc)

      {"end_time_gte", value}, {:ok, acc} ->
        apply_window_filter(:end_time_gte, value, acc)

      {key, value}, {:ok, acc} ->
        query =
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

        {:cont, {:ok, query}}
    end)
    |> case do
      {:ok, query} -> {:ok, Repo.all(query)}
      {:error, message} -> {:error, message}
    end
  end

  # start_time_lte and end_time_gte together select occurrences overlapping a
  # caller-supplied window [end_time_gte, start_time_lte]. The window semantics
  # (e.g. "now until end of today" for a homepage) belong to the caller; this
  # endpoint only compares timestamps.
  defp apply_window_filter(operator, value, acc) do
    case Util.parse_datetime(value) do
      {:ok, datetime} ->
        query =
          case operator do
            :start_time_lte -> from(so in acc, where: so.start_time <= ^datetime)
            :end_time_gte -> from(so in acc, where: so.end_time >= ^datetime)
          end

        {:cont, {:ok, query}}

      :error ->
        {:halt, {:error, "Invalid #{operator} timestamp"}}
    end
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
        from so in query,
          join: s in assoc(so, :session),
          where:
            fragment(
              """
              CASE
              WHEN (?->>'type') = 'continuous'
              THEN (? <= ? AND ? >= ?)
              ELSE (? >= ? AND ? <= ?)
              END
              """,
              # from session table
              s.repeat_schedule,
              so.start_time,
              ^current_time,
              so.end_time,
              ^current_time,
              so.start_time,
              ^today_start,
              so.start_time,
              ^today_end
            )

      "active" ->
        # Active-window lookups filter by end_time (served by the end_time index). Override
        # the base `ORDER BY id` - which makes PostgreSQL walk the primary key and scan
        # ~630K rows to find the few active ones - with temporal ordering. `id` is a
        # deterministic pagination tie-breaker for rows sharing an end_time.
        query
        |> exclude(:order_by)
        |> where([so], so.start_time <= ^current_time and so.end_time >= ^current_time)
        |> order_by([so], asc: so.end_time, asc: so.id)

      _ ->
        query
    end
  end
end
