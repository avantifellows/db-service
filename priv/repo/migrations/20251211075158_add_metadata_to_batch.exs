defmodule Dbservice.Repo.Migrations.AddMetadataToBatch do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :metadata, :map, default: "{}"
    end
  end
end
