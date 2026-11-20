defmodule DbserviceWeb.AlumniJourneyJSON do
  def show(%{journey: journey}), do: render(journey)

  def render(journey) do
    %{
      id: journey.id,
      alumni_id: journey.alumni_id,
      reported_on: journey.reported_on,
      reported_year: journey.reported_year,
      source: journey.source,
      contact_status: journey.contact_status,
      data: journey.data,
      changed_fields: journey.changed_fields,
      actor_email: journey.actor_email,
      actor_role: journey.actor_role,
      notes: journey.notes,
      inserted_at: journey.inserted_at,
      updated_at: journey.updated_at
    }
  end
end
