defmodule Dbservice.Repo.Migrations.AddEnrollmentRecordExclusiveCurrentUniqueIndex do
  @moduledoc """
  Enforces the exclusive-membership invariant at the DB level: at most one
  `is_current = true` `enrollment_record` per `(user_id, group_type)` for the
  exclusive types (`auth_group`, `school`, `grade`). Must run AFTER
  `20260725120000_dedup_exclusive_enrollment_records`; the guard aborts the
  migration if any duplicate remains.

  `batch` is deliberately excluded — it is legitimately non-exclusive (a student
  may hold current batch enrollments across multiple programs, which the
  `centre_students` view depends on).
  """
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM enrollment_record
        WHERE is_current = true
          AND group_type IN ('auth_group','school','grade')
        GROUP BY user_id, group_type
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'enrollment_record has users with >1 current exclusive enrollment; run 20260725120000_dedup_exclusive_enrollment_records first';
      END IF;
    END $$;
    """)

    create unique_index(:enrollment_record, [:user_id, :group_type],
             where: "is_current AND group_type IN ('auth_group','school','grade')",
             name: :enrollment_record_current_exclusive_type_unique
           )
  end

  def down do
    drop_if_exists index(:enrollment_record, [:user_id, :group_type],
                     name: :enrollment_record_current_exclusive_type_unique
                   )
  end
end
