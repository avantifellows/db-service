defmodule Dbservice.Repo.Migrations.RemoveTagIdFromConcept do
  use Ecto.Migration

  def up do
    alter table(:concept) do
      remove :tag_id
    end
  end

  def down do
    alter table(:concept) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
