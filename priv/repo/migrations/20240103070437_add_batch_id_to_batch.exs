defmodule Dbservice.Repo.Migrations.AddBatchIdToBatch do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :batch_id, :string
    end
  end
end
