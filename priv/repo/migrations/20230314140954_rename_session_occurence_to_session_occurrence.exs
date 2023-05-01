defmodule Dbservice.Repo.Migrations.RenameSessionOccurenceToSessionOccurrence do
  use Ecto.Migration

  def change do
    rename table(:session_occurence), to: table(:session_occurrence)
  end
end
