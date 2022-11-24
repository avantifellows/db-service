defmodule Dbservice.Repo.Migrations.RenameUuidInSession do
  use Ecto.Migration

  def change do
    rename table(:session), :uuid, to: :session_id
  end
end
