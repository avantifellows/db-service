defmodule Dbservice.Repo.Migrations.AddLibraryRelatedIndexes do
  use Ecto.Migration

  def change do
    # ===== USER SESSIONS API INDEXES =====
    # Index for get_group_by_group_id_and_type query
    create index(:group, [:id, :type])

    # Index for session filtering by is_active
    create index(:session, [:is_active])

    # Composite index for session filtering by is_active and platform
    create index(:session, [:is_active, :platform])

    # GIN index for JSON meta_data field
    # This helps with queries filtering on meta_data["batch_id"]
    execute "CREATE INDEX IF NOT EXISTS session_meta_data_gin_idx ON session USING GIN (meta_data)"

    # ===== CONTENT-SPECIFIC API INDEXES =====

    # Resource table indexes
    # For get_resource_by_code queries
    create index(:resource, [:code])
    # For type/subtype filtering
    create index(:resource, [:type, :subtype])

    # GIN indexes for JSON fields in resource table
    execute "CREATE INDEX IF NOT EXISTS resource_name_gin_idx ON resource USING GIN (name)"

    execute "CREATE INDEX IF NOT EXISTS resource_type_params_gin_idx ON resource USING GIN (type_params)"

    # Topic table indexes
    # For get_topic_by_code queries
    create index(:topic, [:code])
    execute "CREATE INDEX IF NOT EXISTS topic_name_gin_idx ON topic USING GIN (name)"

    # Chapter table indexes
    # For get_chapter_by_code queries
    create index(:chapter, [:code])
    execute "CREATE INDEX IF NOT EXISTS chapter_name_gin_idx ON chapter USING GIN (name)"

    # Subject table indexes
    execute "CREATE INDEX IF NOT EXISTS subject_name_gin_idx ON subject USING GIN (name)"

    # Curriculum relationship indexes
    # For get_topic_curriculum_by_topic_id_and_curriculum_id
    create index(:topic_curriculum, [:topic_id, :curriculum_id])
    # For get_chapter_curriculum_by_chapter_id_and_curriculum_id
    create index(:chapter_curriculum, [:chapter_id, :curriculum_id])

    # Resource curriculum composite indexes for filtering
    create index(:resource_curriculum, [:curriculum_id, :subject_id])
    create index(:resource_curriculum, [:curriculum_id, :grade_id])
    create index(:resource_curriculum, [:curriculum_id, :subject_id, :grade_id])

    # Problem language indexes
    create index(:problem_lang, [:res_id])
    create index(:problem_lang, [:lang_id])
    create index(:problem_lang, [:res_id, :lang_id])
  end
end
