defmodule Dbservice.Repo.Migrations.CreateBatchTable do
  use Ecto.Migration

  def change do
    create table(:batch) do
      add :name, :string
      add :contact_hours_per_week, :integer

      timestamps()
    end
  end
end
