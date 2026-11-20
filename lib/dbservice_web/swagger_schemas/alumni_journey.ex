defmodule DbserviceWeb.SwaggerSchema.AlumniJourney do
  @moduledoc false

  use PhoenixSwagger

  def alumni_journey_request do
    %{
      AlumniJourneyRequest:
        swagger_schema do
          title("Alumni journey request")
          description("One follow-up with an alumnus")

          properties do
            reported_on(:string, "Date of the follow-up", format: "date", required: true)

            source(:string, "Where the follow-up came from",
              enum: ["initial", "call", "form", "bulk_upload", "correction"],
              required: true
            )

            contact_status(:string, "Outcome of the call")
            data(:object, "Alumni answers to record; only alumni answer fields are accepted")
            actor_email(:string, "Email of the person recording it", required: true)
            actor_role(:string, "LMS role of the person recording it")
            notes(:string, "Free-text notes")
          end

          example(%{
            reported_on: "2026-11-20",
            source: "call",
            contact_status: "Reached",
            data: %{employment_status: "Employed", current_org_name: "Infosys"},
            actor_email: "caller@avantifellows.org",
            actor_role: "alumni_manager",
            notes: "Switched jobs in August"
          })
        end
    }
  end

  def alumni_journey do
    %{
      AlumniJourney:
        swagger_schema do
          title("Alumni journey")
          description("A recorded follow-up with an alumnus")

          properties do
            id(:integer, "Journey row ID")
            alumni_id(:integer, "Alumni ID")
            reported_on(:string, "Date of the follow-up", format: "date")
            reported_year(:integer, "Calendar year of reported_on")
            source(:string, "Where the follow-up came from")
            contact_status(:string, "Outcome of the call")
            data(:object, "Full snapshot of the alumnus's answers after this follow-up")
            changed_fields(:array, "Answers that differ from the previous journey row")
            actor_email(:string, "Email of the person who recorded it")
            actor_role(:string, "LMS role of the person who recorded it")
            notes(:string, "Free-text notes")
            inserted_at(:string, "Created at", format: "date-time")
            updated_at(:string, "Updated at", format: "date-time")
          end
        end
    }
  end
end
