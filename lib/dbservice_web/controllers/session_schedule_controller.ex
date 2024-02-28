defmodule DbserviceWeb.SessionScheduleController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.SessionSchedules
  alias Dbservice.Sessions.SessionSchedule

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.SessionSchedule, as: SwaggerSchemaSessionSchedule

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaSessionSchedule.session_schedule(),
      SwaggerSchemaSessionSchedule.session_schedules()
    )
  end

  swagger_path :index do
    get("/api/session-schedule")

    parameters do
      params(:query, :string, "The id of a session",
        required: false,
        name: "id"
      )
    end

    response(200, "OK", Schema.ref(:SessionSchedules))
  end

  def index(conn, params) do
    today_day_of_week = Calendar.Date.day_of_week_name(Date.utc_today())

    query =
      from(m in SessionSchedule,
        where: m.day_of_week == ^today_day_of_week,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    session_schedule = Repo.all(query)
    render(conn, "index.json", session_schedule: session_schedule)
  end

  swagger_path :create do
    post("/api/session-schedule")

    parameters do
      body(:body, Schema.ref(:SessionSchedule), "Session Schedule to create", required: true)
    end

    response(201, "Created", Schema.ref(:SessionSchedules))
  end

  def create(conn, params) do
    with {:ok, %SessionSchedule{} = session_schedule} <-
           SessionSchedules.create_session_schedule(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.session_schedule_path(conn, :show, session_schedule))
      |> render("show.json", session_schedule: session_schedule)
    end
  end

  swagger_path :show do
    get("/api/session-schedule/{sessionScheduleId}")

    parameters do
      sessionScheduleId(:path, :integer, "The id of the session schedule record", required: true)
    end

    response(200, "OK", Schema.ref(:SessionSchedule))
  end

  def show(conn, %{"id" => id}) do
    session_schedule = SessionSchedules.get_session_schedule!(id)
    render(conn, "show.json", session_schedule: session_schedule)
  end

  swagger_path :update do
    patch("/api/session-schedule/{sessionScheduleId}")

    parameters do
      sessionScheduleId(:path, :integer, "The id of the session schedule record", required: true)
      body(:body, Schema.ref(:SessionSchedule), "Session schedule to create", required: true)
    end

    response(200, "Updated", Schema.ref(:SessionSchedule))
  end

  def update(conn, params) do
    session_schedule = SessionSchedules.get_session_schedule!(params["id"])

    with {:ok, %SessionSchedule{} = session_schedule} <-
           SessionSchedules.update_session_schedule(session_schedule, params) do
      render(conn, "show.json", session_schedule: session_schedule)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/session-schedule/{sessionScheduleId}")

    parameters do
      sessionScheduleId(:path, :integer, "The id of the session schedule record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    session_schedule = SessionSchedules.get_session_schedule!(id)

    with {:ok, %SessionSchedule{}} <- SessionSchedules.delete_session_schedule(session_schedule) do
      send_resp(conn, :no_content, "")
    end
  end
end
