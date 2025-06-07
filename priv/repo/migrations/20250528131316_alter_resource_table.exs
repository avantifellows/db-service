defmodule Dbservice.Repo.Migrations.AlterResourceTable do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      remove :tag_id
      add :tag_ids, {:array, :bigint}
    end
  end
end
