defmodule Dbservice.Repo.Migrations.CreateBatchProgram do
  use Ecto.Migration

  def change do
    create table(:batch_program) do
      add :batch_id, references(:batch, on_delete: :nothing)
      add :program_id, references(:program, on_delete: :nothing)

      timestamps()
    end
  end
end
