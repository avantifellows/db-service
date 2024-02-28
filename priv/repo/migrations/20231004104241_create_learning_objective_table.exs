defmodule Dbservice.Repo.Migrations.CreateLearningObjectiveTable do
  use Ecto.Migration

  def change do
    create table(:learning_objective) do
      add(:title, :string)
      add(:concept_id, references(:concept, on_delete: :nothing))
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
