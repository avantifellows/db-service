defmodule Dbservice.Repo.Migrations.CreateResourceTable do
  use Ecto.Migration

  def change do
    create table(:resource) do
      add(:name, :string)
      add(:type, :string)
      add(:type_params, :map)
      add(:difficulty_level, :string)
      add(:curriculum_id, references(:curriculum, on_delete: :nothing))
      add(:chapter_id, references(:chapter, on_delete: :nothing))
      add(:topic_id, references(:topic, on_delete: :nothing))
      add(:source_id, references(:source, on_delete: :nothing))
      add(:purpose_id, references(:purpose, on_delete: :nothing))
      add(:concept_id, references(:concept, on_delete: :nothing))
      add(:learning_objective_id, references(:learning_objective, on_delete: :nothing))
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
