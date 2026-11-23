defmodule Dbservice.Repo.Migrations.CreateAlumniJourney do
  use Ecto.Migration

  def change do
    create table(:alumni_journey) do
      add :alumni_id, references(:alumni, on_delete: :restrict), null: false
      add :reported_on, :date, null: false

      add :reported_year, :integer,
        generated: "ALWAYS AS (EXTRACT(YEAR FROM reported_on)::int) STORED"

      add :source, :string, size: 50, null: false
      add :contact_status, :string
      add :data, :map, null: false
      add :changed_fields, {:array, :text}, null: false, default: []
      add :actor_email, :string
      add :actor_role, :string
      add :notes, :text

      timestamps()
    end

    create constraint(:alumni_journey, :alumni_journey_source_check,
             check: "source IN ('initial', 'call', 'form', 'bulk_upload', 'correction')"
           )

    create constraint(:alumni_journey, :alumni_journey_data_is_object,
             check: "jsonb_typeof(data) = 'object'"
           )

    # History is read per alumnus in the order it was recorded (id), not by
    # reported_on, since a call may be logged after later changes.
    create index(:alumni_journey, [:alumni_id, :id])
  end
end
