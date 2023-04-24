defmodule DbserviceWeb.SessionOccurenceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.SessionOccurence

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.SessionOccurence, as: SwaggerSchemaSessionOccurrence

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
    response(200, "OK", Schema.ref(:SessionOccurences))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    session_occurence =
      Enum.reduce(param, SessionOccurence, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", session_occurence: session_occurence)
  end

  swagger_path :create do
    post("/api/session-occurrence")

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
    get("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurence record", required: true)
    end

    response(200, "OK", Schema.ref(:SessionOccurenceWithUser))
  end

  def show(conn, %{"id" => id}) do
    session_occurence = Sessions.get_session_occurence!(id)
    render(conn, "show.json", session_occurence: session_occurence)
  end

  swagger_path :update do
    patch("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurence", required: true)
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
    PhoenixSwagger.Path.delete("/api/session-occurrence/{sessionOccurrenceId}")

    parameters do
      sessionOccurrenceId(:path, :integer, "The id of the session occurence record", required: true)
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
