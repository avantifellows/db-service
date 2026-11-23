defmodule Dbservice.Repo.Migrations.AddTranslationToHolisticDictationUsageRecords do
  use Ecto.Migration

  # LMS-owned (af_lms Dictation), still written by LMS with raw SQL; no schema/context here.
  # Both columns stay content-free: no transcript or translated text is stored.
  #
  # - detected_language: the short lower-case language code the speech-to-text provider
  #   reports (e.g. 'hin', 'eng'); NULL when none was reported.
  # - translation: what happened to the transcript after speech-to-text.
  #     not_run = transcription failed or nothing was heard
  #     skipped = the transcript was already English
  #     ok      = translated to English
  #     failed  = translation failed
  #   Existing rows get 'not_run' from the column default.
  #
  # The filename must contain "holistic": af_lms applies `*holistic*.exs` migrations to
  # its local and e2e databases.
  def change do
    alter table(:holistic_mentorship_dictation_usage_records) do
      add :detected_language, :string
      add :translation, :string, null: false, default: "not_run"
    end

    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_detected_language_check,
             check: "detected_language IS NULL OR char_length(detected_language) BETWEEN 1 AND 16"
           )

    create constraint(
             :holistic_mentorship_dictation_usage_records,
             :hm_dictation_usage_translation_check,
             check: "translation IN ('not_run', 'skipped', 'ok', 'failed')"
           )
  end
end
