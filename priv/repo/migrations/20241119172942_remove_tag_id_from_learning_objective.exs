defmodule Dbservice.Repo.Migrations.RemoveTagIdFromLearningObjective do
  use Ecto.Migration

  def up do
    alter table(:learning_objective) do
      remove :tag_id
    end
  end

  def down do
    alter table(:learning_objective) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
