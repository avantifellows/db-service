defmodule Dbservice.Repo.Migrations.RenameSessionIdInSessionOccurrence do
  use Ecto.Migration

  def change do
    rename table(:session_occurence), :session_id, to: :session_fk
  end
end
