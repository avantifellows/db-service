defmodule Dbservice.Repo.Migrations.AddColumnsToSession do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add :platform_id, :string
    end
  end
end
