defmodule Dbservice.Repo.Migrations.AddIndexesOnFkAndLookupFields do
  use Ecto.Migration

  def change do
    # Foreign key indexes
    create index(:group_user, [:user_id])
    create index(:group_user, [:group_id])

    create index(:enrollment_record, [:user_id])
    create index(:enrollment_record, [:group_id])

    create index(:group_session, [:group_id])
    create index(:group_session, [:session_id])

    create index(:user_session, [:user_id])
    create index(:user_session, [:session_id])

    create index(:session_occurrence, [:session_fk])

    # Lookup / filter field indexes
    create index(:user, [:phone])
    create index(:user, [:date_of_birth])

    create index(:student, [:student_id])
    create index(:student, [:apaar_id])
    create index(:student, [:grade_id])

    create index(:session_occurrence, [:start_time])
    create index(:session_occurrence, [:end_time])

    create index(:resource_curriculum, [:resource_id])
    create index(:resource_curriculum, [:subject_id])
    create index(:resource_curriculum, [:grade_id])

    create index(:resource_chapter, [:resource_id])
    create index(:resource_chapter, [:chapter_id])

    create index(:resource_topic, [:resource_id])
    create index(:resource_topic, [:topic_id])

    create index(:resource, [:type])
    create index(:resource, [:subtype])

    create index(:group, [:type])
    create index(:group, [:child_id])

    create index(:enrollment_record, [:group_type])
    create index(:enrollment_record, [:is_current])
    create index(:enrollment_record, [:academic_year])

    create index(:school, [:code])
    create index(:school, [:udise_code])
    create index(:school, [:state])

    create index(:batch, [:batch_id])
  end
end
