defmodule Dbservice.Repo.Migrations.CreateLmsUsageEventsTable do
  use Ecto.Migration

  # LMS product-usage log. LMS-owned like lms_teacher_feedback: the LMS app writes it
  # directly, so there is no schema/context/controller here.
  def change do
    create table(:lms_usage_events) do
      add :event, :string, size: 50, null: false
      add :email, :string, size: 255, null: false
      add :role, :string, size: 50
      add :school_code, :string, size: 20
      add :centre_id, :bigint
      # Event-specific key: tab id, login method, or quiz session id.
      add :detail, :string, size: 255
      add :meta, :map, default: %{}, null: false

      # UTC instant, plus the IST calendar day used for once-a-day events.
      add :occurred_at, :naive_datetime,
        default: fragment("(NOW() AT TIME ZONE 'UTC')"),
        null: false

      add :event_date, :date,
        default: fragment("(NOW() AT TIME ZONE 'Asia/Kolkata')::date"),
        null: false
    end

    create constraint(:lms_usage_events, :event_constraint,
             check: "event IN ('sign_in', 'combined_report_requested', 'tab_viewed')"
           )

    create index(:lms_usage_events, [:event, :event_date])
    create index(:lms_usage_events, [:email])

    # One tab_viewed row per person, tab, school/centre and day.
    execute(
      """
      CREATE UNIQUE INDEX lms_usage_events_tab_daily_unique ON lms_usage_events
        (email, detail, event_date, COALESCE(school_code, ''), COALESCE(centre_id, 0))
        WHERE event = 'tab_viewed'
      """,
      "DROP INDEX lms_usage_events_tab_daily_unique"
    )
  end
end
