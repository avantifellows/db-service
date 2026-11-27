defmodule Dbservice.Repo.Migrations.HardenBlendedLearningMappingTables do
  use Ecto.Migration

  # Tightens the database rules on the two Blended Learning assignment tables, the
  # Mentor-Mentee Mappings and the Mentor Supervisions, which af_lms writes over plain
  # SQL as well as db-service:
  #
  # - academic_year must be YYYY-YYYY with consecutive years, e.g. 2026-2027.
  # - assignment_source, end_source and end_reason must not be whitespace only (they
  #   were only checked against '').
  # - an ended row must say who ended it (ended_by_user_id or ended_by_email). The
  #   one exception is a Mapping ended by Dbservice.BlendedLearning.end_active_mappings/2
  #   when a Student drops out or is archived: no person did that, and its end_source
  #   says which system did. Supervisions have no system end.
  # - the periods [started_at, ended_at) of one Student's Mappings, or one supervisor
  #   and Mentor's Supervisions, in an academic year must not overlap. A reassignment
  #   ends the old row exactly where the new one starts, which does not overlap, and a
  #   row ended at its own start is an empty period, which overlaps nothing.
  # - updated_at moves on every UPDATE, including a plain-SQL one that does not set it.

  @mappings "blended_learning_mentor_mentee_mappings"
  @supervisions "blended_learning_mentor_supervisions"

  # Dbservice.BlendedLearning's @eligibility_end_source.
  @system_end_source "db_service_student_eligibility"

  @academic_year_check """
  CASE
    WHEN academic_year ~ '^[0-9]{4}-[0-9]{4}$'
      THEN substring(academic_year FROM 6 FOR 4)::integer =
           substring(academic_year FROM 1 FOR 4)::integer + 1
    ELSE false
  END
  """

  @lifecycle_check """
  assignment_source ~ '[^[:space:]]' AND
  (
    ended_at IS NULL AND ended_by_user_id IS NULL AND ended_by_email IS NULL AND
    end_source IS NULL AND end_reason IS NULL AND end_audit_reason IS NULL
    OR
    ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source ~ '[^[:space:]]' AND
    end_reason IS NOT NULL AND end_reason ~ '[^[:space:]]' AND ended_at >= started_at
  )
  """

  # As created by 20260921120000 and 20261112120442; restored on rollback.
  @previous_lifecycle_check """
  assignment_source <> '' AND
  (
    ended_at IS NULL AND ended_by_user_id IS NULL AND ended_by_email IS NULL AND
    end_source IS NULL AND end_reason IS NULL AND end_audit_reason IS NULL
    OR
    ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source <> '' AND
    end_reason IS NOT NULL AND end_reason <> '' AND ended_at >= started_at
  )
  """

  @period "tsrange(started_at, ended_at, '[)') WITH &&"

  def up do
    # btree_gist lets the exclusion constraints compare the id and academic_year
    # columns with = alongside the period's &&.
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    create constraint(@mappings, :blm_mappings_academic_year_format_check,
             check: @academic_year_check
           )

    create constraint(@supervisions, :blm_supervisions_academic_year_format_check,
             check: @academic_year_check
           )

    drop constraint(@mappings, :blm_mappings_lifecycle_check)
    create constraint(@mappings, :blm_mappings_lifecycle_check, check: @lifecycle_check)

    drop constraint(@supervisions, :blm_supervisions_lifecycle_check)
    create constraint(@supervisions, :blm_supervisions_lifecycle_check, check: @lifecycle_check)

    create constraint(@mappings, :blm_mappings_ended_by_check,
             check: """
             ended_at IS NULL OR ended_by_user_id IS NOT NULL OR ended_by_email IS NOT NULL OR
             end_source = '#{@system_end_source}'
             """
           )

    create constraint(@supervisions, :blm_supervisions_ended_by_check,
             check: """
             ended_at IS NULL OR ended_by_user_id IS NOT NULL OR ended_by_email IS NOT NULL
             """
           )

    create constraint(@mappings, :blm_mappings_no_overlapping_periods,
             exclude: "gist (student_id WITH =, academic_year WITH =, #{@period})"
           )

    create constraint(@supervisions, :blm_supervisions_no_overlapping_periods,
             exclude:
               "gist (supervisor_user_id WITH =, mentor_user_id WITH =, academic_year WITH =, #{@period})"
           )

    # clock_timestamp(), not now(): now() is the transaction's start, so a long
    # transaction would stamp a row earlier than one committed before it. Truncated
    # because a timestamp(0) column rounds, which could stamp a time still to come.
    # The WHEN clause skips an UPDATE that changes nothing, so it leaves updated_at.
    execute("""
    CREATE FUNCTION blended_learning_touch_updated_at()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.updated_at := date_trunc('second', timezone('UTC', clock_timestamp()));
      RETURN NEW;
    END;
    $$;
    """)

    for {table, trigger} <- triggers() do
      execute("""
      CREATE TRIGGER #{trigger}
      BEFORE UPDATE ON #{table}
      FOR EACH ROW
      WHEN (OLD.* IS DISTINCT FROM NEW.*)
      EXECUTE FUNCTION blended_learning_touch_updated_at()
      """)
    end
  end

  def down do
    for {table, trigger} <- triggers() do
      execute("DROP TRIGGER #{trigger} ON #{table}")
    end

    execute("DROP FUNCTION blended_learning_touch_updated_at()")

    drop constraint(@supervisions, :blm_supervisions_no_overlapping_periods)
    drop constraint(@mappings, :blm_mappings_no_overlapping_periods)
    drop constraint(@supervisions, :blm_supervisions_ended_by_check)
    drop constraint(@mappings, :blm_mappings_ended_by_check)

    drop constraint(@supervisions, :blm_supervisions_lifecycle_check)

    create constraint(@supervisions, :blm_supervisions_lifecycle_check,
             check: @previous_lifecycle_check
           )

    drop constraint(@mappings, :blm_mappings_lifecycle_check)

    create constraint(@mappings, :blm_mappings_lifecycle_check, check: @previous_lifecycle_check)

    drop constraint(@supervisions, :blm_supervisions_academic_year_format_check)
    drop constraint(@mappings, :blm_mappings_academic_year_format_check)

    # btree_gist stays: other objects may come to depend on it.
  end

  defp triggers do
    [
      {@mappings, "blm_mappings_touch_updated_at"},
      {@supervisions, "blm_supervisions_touch_updated_at"}
    ]
  end
end
