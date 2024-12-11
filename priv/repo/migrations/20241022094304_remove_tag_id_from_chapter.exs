defmodule Dbservice.Repo.Migrations.RemoveTagIdFromChapter do
  use Ecto.Migration

  def up do
    alter table(:chapter) do
      remove :tag_id
    end
  end

  def down do
    alter table(:chapter) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
