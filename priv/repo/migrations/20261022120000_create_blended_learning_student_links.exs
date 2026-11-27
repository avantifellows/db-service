defmodule Dbservice.Repo.Migrations.CreateBlendedLearningStudentLinks do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Student Links
  # (Profile Doc URL, Screener URL and legacy last-contact date) directly over SQL, so
  # there is no schema/context/controller here. The table is mutable.
  #
  # legacy_last_contact_on is the latest dated conversation in the Student's Profile Doc,
  # loaded by the af_lms links script (re-runnable); NULL when the doc has none.
  #
  # Blended Learning migration 1 of 8.

  @table :blended_learning_student_links

  def change do
    create table(@table) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :profile_doc_url, :text
      add :screener_url, :text
      add :legacy_last_contact_on, :date

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(@table, [:student_id], name: :bl_student_links_student_unique)

    create constraint(@table, :bl_student_links_profile_doc_url_check,
             check: "profile_doc_url IS NULL OR profile_doc_url ~ '^https://[^[:space:]]+$'"
           )

    create constraint(@table, :bl_student_links_screener_url_check,
             check: "screener_url IS NULL OR screener_url ~ '^https://[^[:space:]]+$'"
           )
  end
end
