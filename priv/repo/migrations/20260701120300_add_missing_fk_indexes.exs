defmodule Dbservice.Repo.Migrations.AddMissingFkIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # 12+ tables have foreign-key/lookup columns that are joined/filtered on hot paths but have
  # no index, forcing sequential scans. All built CONCURRENTLY so the tables stay writable
  # during the build; create_if_not_exists keeps the migration re-runnable if interrupted.
  def change do
    # Hot-path tables (highest priority)
    create_if_not_exists index(:resource_concept, [:resource_id], concurrently: true)
    create_if_not_exists index(:resource_concept, [:concept_id], concurrently: true)
    create_if_not_exists index(:problem_lang, [:res_id], concurrently: true)
    create_if_not_exists index(:problem_lang, [:lang_id], concurrently: true)
    create_if_not_exists index(:resource, [:teacher_id], concurrently: true)
    create_if_not_exists index(:resource, [:code], concurrently: true)
    create_if_not_exists index(:student_exam_record, [:student_id], concurrently: true)
    create_if_not_exists index(:student_exam_record, [:exam_id], concurrently: true)

    # Join tables
    create_if_not_exists index(:chapter_curriculum, [:chapter_id], concurrently: true)
    create_if_not_exists index(:chapter_curriculum, [:curriculum_id], concurrently: true)
    create_if_not_exists index(:topic_curriculum, [:topic_id], concurrently: true)
    create_if_not_exists index(:topic_curriculum, [:curriculum_id], concurrently: true)
    create_if_not_exists index(:school_batch, [:school_id], concurrently: true)
    create_if_not_exists index(:school_batch, [:batch_id], concurrently: true)

    # Remaining
    create_if_not_exists index(:learning_objective, [:concept_id], concurrently: true)
    create_if_not_exists index(:school, [:user_id], concurrently: true)
    create_if_not_exists index(:resource_curriculum, [:curriculum_id], concurrently: true)
    create_if_not_exists index(:cutoffs, [:college_id], concurrently: true)
    create_if_not_exists index(:cutoffs, [:branch_id], concurrently: true)
    create_if_not_exists index(:cutoffs, [:demographic_profile_id], concurrently: true)
  end
end
