defmodule Dbservice.Repo.Migrations.CreateResourceCurriculum do
  use Ecto.Migration

  def change do
    # Create the new table
    create table(:resource_curriculum) do
      add :resource_id, references(:resource, on_delete: :nothing)
      add :curriculum_id, references(:curriculum, on_delete: :nothing)
      add :grade_id, references(:grade, on_delete: :nothing)
      add :subject_id, references(:subject, on_delete: :nothing)
      add :difficulty_level, :string

      timestamps()
    end

    # Migrate existing data including grade_id and subject_id from chapter table
    execute """
    INSERT INTO resource_curriculum (resource_id, curriculum_id, grade_id, subject_id, difficulty_level, inserted_at, updated_at)
    SELECT r.id, r.curriculum_id, c.grade_id, c.subject_id, r.difficulty_level, NOW(), NOW()
    FROM resource r
    LEFT JOIN chapter c ON r.chapter_id = c.id
    WHERE r.curriculum_id IS NOT NULL
    """

    alter table(:resource) do
      remove :curriculum_id
      remove :difficulty_level
    end
  end
end
