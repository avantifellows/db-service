defmodule Dbservice.Repo.Migrations.CreateLmsVisitConcerns do
  use Ecto.Migration

  # LMS #470 (School Visit Summary): durable Visit Concerns and Visit Highlights
  # grouped from PM Visit free text by the etl-next flow. db-service owns this schema
  # and the machine APIs etl-next calls; af_lms reads these tables directly. There is
  # no schema/context here.
  #
  # DDL parity: names, types, defaults and the trigger must match the af_lms e2e
  # mirror `20261027140000_add_lms_visit_concerns.sql`. Timestamps are
  # `timestamp(0) without time zone` holding UTC.
  def change do
    create table(:lms_visit_concerns) do
      # A record belongs to a School, not a Centre; no FK.
      add :school_code, :text, null: false
      add :kind, :text, null: false
      add :text, :text, null: false
      add :status, :text

      timestamps(default: fragment("now()"), null: false)
    end

    # A Mention links a record to a Visit that raised it. Visits are only soft-deleted,
    # so the Visit FK does not cascade.
    create table(:lms_visit_concern_mentions) do
      add :concern_id, references(:lms_visit_concerns, on_delete: :delete_all), null: false
      add :visit_id, references(:lms_pm_school_visits, on_delete: :nothing), null: false
      add :snippet, :text, null: false

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    # Resolution history: af_lms writes resolved/reopened/comment events; db-service
    # writes auto_reopened events naming the Visit that raised a resolved Concern
    # again. The FK does not cascade, so a record with events cannot be deleted.
    create table(:lms_visit_concern_events) do
      add :concern_id, references(:lms_visit_concerns, on_delete: :nothing), null: false
      add :kind, :text, null: false
      add :body, :text
      add :author_email, :text
      add :visit_id, references(:lms_pm_school_visits, on_delete: :nothing)

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    # The fingerprint and prompt version a Visit was last summarised with. Written only
    # by db-service, which always sets summarised_at itself.
    create table(:lms_visit_note_summaries, primary_key: false) do
      add :visit_id, references(:lms_pm_school_visits, on_delete: :nothing), primary_key: true
      add :fingerprint, :text, null: false
      add :prompt_version, :text, null: false
      add :summarised_at, :naive_datetime, null: false
    end

    create index(:lms_visit_concerns, [:school_code, :kind])
    create unique_index(:lms_visit_concern_mentions, [:concern_id, :visit_id])
    create index(:lms_visit_concern_mentions, [:visit_id])
    create index(:lms_visit_concern_events, [:concern_id, :inserted_at])

    create constraint(:lms_visit_concerns, :lms_visit_concerns_kind_check,
             check: "kind IN ('concern', 'highlight')"
           )

    create constraint(:lms_visit_concerns, :lms_visit_concerns_status_check,
             check: "status IN ('open', 'resolved')"
           )

    # Highlights have no status; Concerns always have one.
    create constraint(:lms_visit_concerns, :lms_visit_concerns_kind_status_check,
             check: "(kind = 'concern') = (status IS NOT NULL)"
           )

    create constraint(:lms_visit_concern_events, :lms_visit_concern_events_kind_check,
             check: "kind IN ('resolved', 'reopened', 'comment', 'auto_reopened')"
           )

    # Only an auto_reopened event names a Visit; it has no author and no body.
    create constraint(
             :lms_visit_concern_events,
             :lms_visit_concern_events_auto_reopened_check,
             check:
               "(kind = 'auto_reopened') = (author_email IS NULL AND visit_id IS NOT NULL AND body IS NULL)"
           )

    # Not in the af_lms mirror yet. Human events carry a non-blank body of at most 2000
    # characters after trimming. The IS NOT NULL is needed because a CHECK that
    # evaluates to NULL passes; `~ '[^[:space:]]'` rejects tab/newline-only text,
    # which btrim (spaces only) would let through.
    create constraint(:lms_visit_concern_events, :lms_visit_concern_events_body_check,
             check: """
             kind = 'auto_reopened' OR
             (body IS NOT NULL AND body ~ '[^[:space:]]' AND char_length(btrim(body)) <= 2000)
             """
           )

    # Human events have a non-blank author and never name a Visit.
    create constraint(:lms_visit_concern_events, :lms_visit_concern_events_author_check,
             check: """
             kind = 'auto_reopened' OR
             (author_email IS NOT NULL AND author_email ~ '[^[:space:]]' AND visit_id IS NULL)
             """
           )

    execute(
      """
      CREATE FUNCTION lms_protect_visit_concern_events()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Visit concern events are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION lms_protect_visit_concern_events()"
    )

    execute(
      """
      CREATE TRIGGER lms_visit_concern_events_append_only
      BEFORE UPDATE OR DELETE ON lms_visit_concern_events
      FOR EACH ROW EXECUTE FUNCTION lms_protect_visit_concern_events()
      """,
      "DROP TRIGGER lms_visit_concern_events_append_only ON lms_visit_concern_events"
    )
  end
end
