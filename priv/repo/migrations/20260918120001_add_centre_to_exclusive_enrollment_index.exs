defmodule Dbservice.Repo.Migrations.AddCentreToExclusiveEnrollmentIndex do
  @moduledoc """
  Extends `enrollment_record_current_exclusive_type_unique` (20260725120002) to
  cover `centre`, so "a student belongs to one centre at a time" is enforced by
  the database and not only by `EnrollmentService`.

  Product confirmed the rule on 2026-09-17, and the data already agrees: the
  production check behind the 2026-09-10 `centre_students` rewrite found zero
  students matching more than one active centre out of 5,446. No centre
  enrollment records exist yet either, so no dedup step is needed - unlike
  20260725120000, which had to clean up school/grade/auth_group first.

  Adding it now rather than after the backfill is deliberate: the group_user
  duplication cleaned up in 20260725120001 happened precisely because the
  invariant lived in application code while the rows accumulated underneath it.

  `batch` remains excluded - a student legitimately holds current batch
  enrollments across multiple programs, which `centre_students` depends on.
  """
  use Ecto.Migration

  @index_name :enrollment_record_current_exclusive_type_unique
  @old_types "'auth_group','school','grade'"
  @new_types "'auth_group','school','grade','centre'"

  def up, do: rebuild_index(@new_types)
  def down, do: rebuild_index(@old_types)

  # Repoints the partial unique index at `types`, refusing to do so if the
  # target predicate would already be violated by existing rows.
  defp rebuild_index(types) do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM enrollment_record
        WHERE is_current = true
          AND group_type IN (#{types})
        GROUP BY user_id, group_type
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'enrollment_record has users with >1 current exclusive enrollment; dedup before changing the exclusive index';
      END IF;
    END $$;
    """)

    drop_if_exists(index(:enrollment_record, [:user_id, :group_type], name: @index_name))

    create unique_index(:enrollment_record, [:user_id, :group_type],
             where: "is_current AND group_type IN (#{types})",
             name: @index_name
           )
  end
end
