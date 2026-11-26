defmodule Dbservice.Repo.Migrations.CreateAiTestInsightTables do
  use Ecto.Migration

  # AI Test Insights (af_lms #549, governed by af_lms ADR 0015). Consumers:
  # af_lms #550 and #551, ai-mentorship-guide #135.
  #
  # Ownership: db-service owns this DDL and exposes no API, Ecto schema or context
  # for these tables.
  #
  # - `ai_test_insight_requests`: the LMS inserts and reads it; AI Mentorship Guide
  #   reads it and updates progress (state, Item link, times, outcome code). This row
  #   is the whole contract between the two apps.
  # - `ai_test_insight_sessions`: the LMS reads and writes it (Session Notes, draft
  #   then submitted). AI Mentorship Guide does not touch it.
  # - `ai_test_insight_session_note_audits`: the LMS inserts one content-free row for
  #   each submit and each later edit of Session Notes. Rows are append-only (trigger
  #   below). AI Mentorship Guide does not touch it.
  #
  # Timestamps are `timestamp(0) without time zone` holding UTC. The defaults say
  # `now() AT TIME ZONE 'UTC'`, because a plain `now()` stores the connection's
  # local time. There is no `updated_at` trigger: writers set `updated_at`, and
  # every other time, in their own SQL with the same expression.
  def change do
    # Target of the Insight Request's (inference_item_id, student_id) foreign key.
    # The one change this migration makes to an AI Mentorship Guide table.
    create unique_index(:acad_mentorship_inference_items, [:id, :student_id],
             name: :am_items_id_student_unique
           )

    create table(:ai_test_insight_requests) do
      add :request_key, :text, null: false
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :text, null: false
      add :requested_by_user_id, references(:user, on_delete: :nothing), null: false
      # Ticked tests, newest first; same name and type as
      # acad_mentorship_inference_items.selected_test_ids.
      add :selected_test_ids, :map, null: false
      # Copy of earlier Session Notes for the generator; the LMS and the generator
      # agree the element shape and the 5-session cap.
      add :notes_snapshot, :map, null: false, default: fragment("'[]'::jsonb")
      add :state, :text, null: false, default: "queued"
      add :outcome_code, :text
      # An FK from this LMS-owned table to an AI Mentorship Guide table, on purpose:
      # the generator cannot delete an Item a Test Insight depends on. The composite
      # key, on am_items_id_student_unique, makes the Item belong to the same Student.
      # MATCH SIMPLE (the default) lets a null inference_item_id pass.
      add :inference_item_id,
          references(:acad_mentorship_inference_items,
            with: [student_id: :student_id],
            on_delete: :nothing
          )

      # The time the LMS's 20-minute stall rule counts from.
      add :requested_at, :naive_datetime, null: false, default: utc_now()
      add :started_at, :naive_datetime
      add :finished_at, :naive_datetime

      timestamps(default: utc_now(), null: false)
    end

    # What each state requires. An unknown state matches no branch, so there is no
    # separate state-list CHECK. `running` may not have an Item yet. `no_data` and
    # `failed` need no Item and no start time, so the LMS can fail a request the
    # generator never finished (it must do so before a retry, because the stalled
    # row still holds the Student's one running slot). State order is not enforced.
    create constraint(:ai_test_insight_requests, :ati_requests_lifecycle_check,
             check: """
                (state = 'queued'    AND started_at IS NULL AND finished_at IS NULL
                                     AND inference_item_id IS NULL AND outcome_code IS NULL)
             OR (state = 'running'   AND started_at IS NOT NULL AND finished_at IS NULL
                                     AND outcome_code IS NULL)
             OR (state = 'completed' AND started_at IS NOT NULL AND finished_at IS NOT NULL
                                     AND inference_item_id IS NOT NULL AND outcome_code IS NULL)
             OR (state IN ('no_data', 'failed') AND finished_at IS NOT NULL
                                     AND outcome_code IS NOT NULL)
             """
           )

    # A non-empty array whose every element is a non-empty string. The CASE runs the
    # array functions only on an array, so an object or a scalar fails this CHECK
    # instead of raising "cannot get array length of a non-array".
    # jsonb_path_exists needs Postgres 12 or later.
    create constraint(:ai_test_insight_requests, :ati_requests_selected_test_ids_check,
             check: """
             CASE
               WHEN jsonb_typeof(selected_test_ids) = 'array'
               THEN jsonb_array_length(selected_test_ids) > 0
                    AND NOT jsonb_path_exists(
                      selected_test_ids,
                      'strict $[*] ? (@.type() != "string" || @ == "")'
                    )
               ELSE false
             END
             """
           )

    # A UUID fits.
    create constraint(:ai_test_insight_requests, :ati_requests_request_key_check,
             check: "request_key ~ '^[A-Za-z0-9_-]{1,64}$'"
           )

    # Same rule as enrollment_record_academic_year_format: the CASE runs the integer
    # casts only on a value of the right shape.
    create constraint(:ai_test_insight_requests, :ati_requests_academic_year_check,
             check: """
             CASE
               WHEN academic_year ~ '^[0-9]{4}-[0-9]{4}$'
               THEN left(academic_year, 4)::int + 1 = right(academic_year, 4)::int
               ELSE false
             END
             """
           )

    # The database does not check the element shape or the 5-session cap.
    create constraint(:ai_test_insight_requests, :ati_requests_notes_snapshot_check,
             check: "jsonb_typeof(notes_snapshot) = 'array'"
           )

    # Required for no_data and failed (lifecycle CHECK). The code list is not
    # restricted here.
    create constraint(:ai_test_insight_requests, :ati_requests_outcome_code_check,
             check: "outcome_code IS NULL OR outcome_code ~ '^[a-z][a-z0-9_]{0,63}$'"
           )

    create unique_index(:ai_test_insight_requests, [:request_key], name: :ati_requests_key_unique)

    # One queued or running request per Student. Also serves the generator's scan for
    # queued requests on start-up, so there is no separate state index.
    create unique_index(:ai_test_insight_requests, [:student_id],
             where: "state IN ('queued', 'running')",
             name: :ati_requests_active_student_unique
           )

    # One request per generator Item.
    create unique_index(:ai_test_insight_requests, [:inference_item_id],
             where: "inference_item_id IS NOT NULL",
             name: :ati_requests_inference_item_unique
           )

    # Target of the Insight Session's (insight_request_id, student_id) foreign key.
    create unique_index(:ai_test_insight_requests, [:id, :student_id],
             name: :ati_requests_id_student_unique
           )

    # A Student's history, the tab counts and the "same Student, same tests" lookup.
    create index(:ai_test_insight_requests, [:student_id, :requested_at],
             name: :ati_requests_student_requested_idx
           )

    create table(:ai_test_insight_sessions) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :text, null: false
      add :author_user_id, references(:user, on_delete: :nothing), null: false
      add :state, :text, null: false, default: "draft"
      # The day the conversation happened.
      add :session_date, :date
      add :areas_of_concern, :text
      add :immediate_actions, :text
      add :other_notes, :text
      # The Test Insight that was open, if any. The composite key, on
      # ati_requests_id_student_unique, makes the request belong to the same Student.
      # MATCH SIMPLE (the default) lets a null insight_request_id pass.
      add :insight_request_id,
          references(:ai_test_insight_requests,
            with: [student_id: :student_id],
            on_delete: :nothing
          )

      add :revision, :integer, null: false, default: 1
      # First submit time; later edits do not change it.
      add :submitted_at, :naive_datetime

      timestamps(default: utc_now(), null: false)
    end

    # A draft may be empty. A submitted session needs a date, a submit time and
    # non-blank Areas of concern and Immediate actions; Other notes stays optional.
    # The COALESCE is required: a CHECK whose expression is null passes, so without
    # it a null note field would be accepted. An unknown state matches no branch.
    # The "not in the future" date rule is the LMS's (India time; this clock is UTC).
    create constraint(:ai_test_insight_sessions, :ati_sessions_lifecycle_check,
             check: """
                (state = 'draft' AND submitted_at IS NULL)
             OR (state = 'submitted' AND submitted_at IS NOT NULL AND session_date IS NOT NULL
                 AND COALESCE(areas_of_concern, '')  ~ '[^[:space:]]'
                 AND COALESCE(immediate_actions, '') ~ '[^[:space:]]')
             """
           )

    # Same rule and form as ati_requests_academic_year_check.
    create constraint(:ai_test_insight_sessions, :ati_sessions_academic_year_check,
             check: """
             CASE
               WHEN academic_year ~ '^[0-9]{4}-[0-9]{4}$'
               THEN left(academic_year, 4)::int + 1 = right(academic_year, 4)::int
               ELSE false
             END
             """
           )

    # Optimistic saves: the LMS updates WHERE id = $1 AND revision = $2 and sets
    # revision = revision + 1, with no further constraint.
    create constraint(:ai_test_insight_sessions, :ati_sessions_revision_check,
             check: "revision > 0"
           )

    # One draft per author per Student; a new draft is allowed once it is submitted.
    create unique_index(:ai_test_insight_sessions, [:author_user_id, :student_id],
             where: "state = 'draft'",
             name: :ati_sessions_author_student_draft_unique
           )

    # The timeline, the tab counts and the last-session date.
    create index(:ai_test_insight_sessions, [:student_id, :state, :session_date],
             name: :ati_sessions_student_state_date_idx
           )

    # Test Insights that have no Insight Session.
    create index(:ai_test_insight_sessions, [:insight_request_id],
             name: :ati_sessions_insight_request_idx
           )

    # One row per submit and per later edit: who, when and which revision. No note
    # text, no reason and no before or after values. Draft saves write no row, so a
    # draft can still be deleted; the session FK does not cascade, so a session with
    # an audit row cannot be.
    create table(:ai_test_insight_session_note_audits) do
      add :session_id, references(:ai_test_insight_sessions, on_delete: :nothing), null: false
      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :action, :text, null: false
      # The session's revision after the action.
      add :revision, :integer, null: false
      add :occurred_at, :naive_datetime, null: false, default: utc_now()

      # Rows never change, so there is no updated_at.
      timestamps(default: utc_now(), null: false, updated_at: false)
    end

    # The names the LMS already uses for Holistic notes.
    create constraint(:ai_test_insight_session_note_audits, :ati_session_note_audits_action_check,
             check: "action IN ('submitted', 'submitted_edited')"
           )

    create constraint(
             :ai_test_insight_session_note_audits,
             :ati_session_note_audits_revision_check,
             check: "revision > 0"
           )

    # One row per session revision.
    create unique_index(:ai_test_insight_session_note_audits, [:session_id, :revision],
             name: :ati_session_note_audits_session_revision_unique
           )

    # A session is submitted once; later edits are submitted_edited.
    create unique_index(:ai_test_insight_session_note_audits, [:session_id],
             where: "action = 'submitted'",
             name: :ati_session_note_audits_one_submit_unique
           )

    # Audit rows are append-only, as in the Holistic and Visit Concern audit tables.
    # With the non-cascading session FK this also makes a submitted session
    # undeletable. 23514 is check_violation. There is no privacy erasure exception.
    execute(
      """
      CREATE FUNCTION ati_protect_session_note_audits()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'AI Test Insight Session Note audits are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION ati_protect_session_note_audits()"
    )

    execute(
      """
      CREATE TRIGGER ati_session_note_audits_immutable
      BEFORE UPDATE OR DELETE ON ai_test_insight_session_note_audits
      FOR EACH ROW EXECUTE FUNCTION ati_protect_session_note_audits()
      """,
      "DROP TRIGGER ati_session_note_audits_immutable ON ai_test_insight_session_note_audits"
    )
  end

  defp utc_now, do: fragment("(now() AT TIME ZONE 'UTC')")
end
