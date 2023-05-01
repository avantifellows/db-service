defmodule Dbservice.Repo.Migrations.CreateBatch do
  use Ecto.Migration

  def change do
    create table(:batch) do
      add :name, :string

      timestamps()
    end
  end
end
