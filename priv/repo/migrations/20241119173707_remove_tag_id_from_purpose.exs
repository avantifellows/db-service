defmodule Dbservice.Repo.Migrations.RemoveTagIdFromPurpose do
  use Ecto.Migration

  def up do
    alter table(:purpose) do
      remove :tag_id
    end
  end

  def down do
    alter table(:purpose) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
