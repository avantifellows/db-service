defmodule Dbservice.Repo.Migrations.UpdateBatchTable do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :start_date, :date
      add :end_date, :date
      add :program_id, references(:program)
    end

    drop table(:batch_program)
  end
end
