defmodule Dbservice.Repo.Migrations.AddLegacyLastContactOnToBlendedLearningStudentLinks do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning Student Links: af_lms reads and
  # writes it over SQL, so there is no schema/context/controller here.
  #
  # An exact legacy last-contact date for a Student: the latest dated
  # conversation in the Student's Profile Doc, loaded by the af_lms links script
  # (re-runnable). NULL when the doc cannot be read or has no dated
  # conversation. Talk to first uses it after the latest in-app Conversation,
  # instead of legacy_last_contact_month, whose month precision puts a whole
  # month's Students into Talk to first on the same day.
  #
  # Nullable with no default and no CHECK, so adding it is metadata-only and
  # does not scan the table. legacy_last_contact_month is kept as it is.
  #
  # Blended Learning migration 9, after the eight create migrations.

  def change do
    alter table(:blended_learning_student_links) do
      add :legacy_last_contact_on, :date
    end
  end
end
