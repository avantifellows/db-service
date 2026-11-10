defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipDictationUsageRecords do
  use Ecto.Migration

  # LMS-owned (af_lms #500, Dictation): one content-free row per Dictation attempt that
  # reached the speech-to-text provider. LMS inserts the row as 'failed' before the
  # provider call and updates it to its final outcome afterwards, so an attempt killed
  # mid-request still counts toward the Mentor's daily limit. LMS writes these rows
  # directly; there is no schema/context here.
  #
  # Deliberately no Student, Phase, Question, text or audio column. The row is not
  # Student content, so it is outside Holistic privacy erasure.
  #
  # The filename must contain "holistic": af_lms applies `*holistic*.exs` migrations to
  # its local and e2e databases.
  def change do
    create table(:holistic_mentorship_dictation_usage_records) do
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :note_kind, :string, null: false
      add :audio_seconds, :integer, null: false
      add :characters_returned, :integer, null: false, default: 0
      add :outcome, :string, null: false
      add :completed_at, :utc_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    # LMS sums a Mentor's audio_seconds for the current India-time day.
    create index(
             :holistic_mentorship_dictation_usage_records,
             [:mentor_user_id, :inserted_at],
             name: :hm_dictation_usage_mentor_time_idx
           )

    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_note_kind_check,
             check: "note_kind IN ('post_session', 'follow_up')"
           )

    # One recording is capped at two minutes; 125 allows five seconds of timer slop.
    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_audio_seconds_check,
             check: "audio_seconds BETWEEN 1 AND 125"
           )

    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_characters_returned_check,
             check: "characters_returned >= 0"
           )

    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_outcome_check,
             check: "outcome IN ('ok', 'failed', 'nothing_heard')"
           )
  end
end
