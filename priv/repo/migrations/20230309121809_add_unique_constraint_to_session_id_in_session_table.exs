defmodule Dbservice.Repo.Migrations.AddUniqueConstraintToSessionIdInSessionTable do
  use Ecto.Migration

  def change do
    create unique_index(:session, :session_id)
  end
end
