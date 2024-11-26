defmodule Dbservice.Repo.Migrations.RemoveTagIdFromGrade do
  use Ecto.Migration

  def up do
    alter table(:grade) do
      remove :tag_id
    end
  end

  def down do
    alter table(:grade) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
