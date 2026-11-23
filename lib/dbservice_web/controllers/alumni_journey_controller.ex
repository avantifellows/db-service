defmodule DbserviceWeb.AlumniJourneyController do
  use DbserviceWeb, :controller
  use PhoenixSwagger

  alias Dbservice.Alumnis
  alias DbserviceWeb.SwaggerSchema.AlumniJourney, as: SwaggerSchemaAlumniJourney

  action_fallback(DbserviceWeb.FallbackController)

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaAlumniJourney.alumni_journey_request(),
      SwaggerSchemaAlumniJourney.alumni_journey()
    )
  end

  swagger_path :create do
    post("/api/alumni/{alumniId}/journey")

    description("""
    Records one follow-up with an alumnus. Applies `data` to the alumni record and
    appends a journey row with the full snapshot of answers. Blank values never erase
    a recorded answer, except with `source: "correction"`, where a blank clears it.
    `reported_on` is when the call happened: it may be back-dated, but not after
    tomorrow or before 2000. A row is written even if nothing changed.
    `changed_fields` is computed by the server against the latest recorded row.
    """)

    parameters do
      alumniId(:path, :integer, "The id of the alumni record", required: true)
      body(:body, Schema.ref(:AlumniJourneyRequest), "The follow-up to record", required: true)
    end

    response(201, "Created", Schema.ref(:AlumniJourney))
    response(404, "Alumni not found")
    response(422, "Invalid follow-up")
  end

  def create(conn, %{"alumni_id" => alumni_id} = params) do
    with %_{} = alumni <- Alumnis.get_alumni(alumni_id) || {:error, :not_found},
         {:ok, journey} <- Alumnis.record_journey(alumni, Map.delete(params, "alumni_id")) do
      conn
      |> put_status(:created)
      |> render(:show, journey: journey)
    end
  end
end
