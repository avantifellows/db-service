defmodule Dbservice.Repo.Migrations.AddConfigToProgram do
  use Ecto.Migration

  def change do
    alter table(:program) do
      add :config, :map, default: "{}"
    end
  end
end
