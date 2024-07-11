defmodule Dbservice.Repo.Migrations.CreateSchoolBatchTable do
  use Ecto.Migration

  def change do
    create table(:school_batch) do
      add :school_id, references(:school, on_delete: :nothing)
      add :batch_id, references(:batch, on_delete: :nothing)

      timestamps()
    end
  end
end
