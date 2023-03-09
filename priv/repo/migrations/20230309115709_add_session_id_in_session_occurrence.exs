defmodule Dbservice.Repo.Migrations.AddSessionIdInSessionOccurrence do
  use Ecto.Migration

  def change do
    alter table(:session_occurence) do
      add :session_id, :string
    end
  end
end
