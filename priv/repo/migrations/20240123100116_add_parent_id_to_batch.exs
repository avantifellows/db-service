defmodule Dbservice.Repo.Migrations.AddParentIdToBatch do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :parent_id, references(:batch, on_delete: :nothing)
    end
  end
end
