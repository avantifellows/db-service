defmodule Dbservice.Repo.Migrations.AddBatchIdToSession do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add :class_batch_id, references(:batch, on_delete: :nothing)
    end
  end
end
