defmodule Dbservice.Repo.Migrations.RenameSessionOccurenceToSessionOccurrenceInUserSession do
  use Ecto.Migration

  def change do
    rename table(:user_session), :session_occurence_id, to: :session_occurrence_id
  end
end
