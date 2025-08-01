defmodule Dbservice.Repo.Migrations.RemoveTagIdFromCurriculum do
  use Ecto.Migration

  def up do
    alter table(:curriculum) do
      remove :tag_id
    end
  end

  def down do
    alter table(:curriculum) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
