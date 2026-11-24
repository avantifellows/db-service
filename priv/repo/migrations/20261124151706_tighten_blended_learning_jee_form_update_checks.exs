defmodule Dbservice.Repo.Migrations.TightenBlendedLearningJeeFormUpdateChecks do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes this table
  # directly over SQL, so there is no schema/context/controller here.
  #
  # Tightens two CHECK constraints on blended_learning_jee_form_updates:
  #
  # - reasons: reject duplicate reason codes (such as {other,other}) on a not_filled row.
  #   PostgreSQL forbids subqueries directly inside CHECK constraints, so a small IMMUTABLE
  #   SQL helper checks that the array has no repeated elements (returning true for NULL).
  # - academic_year: replace the non-blank check with the strict consecutive YYYY-YYYY check
  #   used on the Blended Learning Mapping and Supervision tables (e.g. 2026-2027).
  #
  # Rolling back drops the new constraints and helper function, and restores the earlier
  # non-blank academic_year check.

  @updates :blended_learning_jee_form_updates

  @academic_year_check """
  CASE
    WHEN academic_year ~ '^[0-9]{4}-[0-9]{4}$'
      THEN substring(academic_year FROM 6 FOR 4)::integer =
           substring(academic_year FROM 1 FOR 4)::integer + 1
    ELSE false
  END
  """

  # As created by 20261124122211; restored on rollback.
  @previous_academic_year_check "academic_year ~ '[^[:space:]]'"

  def up do
    # Requires an element type with an equality operator (e.g. not json).
    execute("""
    CREATE FUNCTION blended_learning_array_has_no_duplicates(arr anyarray)
    RETURNS boolean
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE
    AS $$
      SELECT
        arr IS NULL
        OR cardinality(arr) = (
          SELECT count(*) FROM (SELECT DISTINCT elem FROM unnest(arr) AS elem) AS distinct_elems
        );
    $$;
    """)

    create constraint(@updates, :bl_jee_form_updates_reasons_unique_check,
             check: "reasons IS NULL OR blended_learning_array_has_no_duplicates(reasons)"
           )

    drop constraint(@updates, :bl_jee_form_updates_academic_year_check)

    create constraint(@updates, :bl_jee_form_updates_academic_year_format_check,
             check: @academic_year_check
           )
  end

  def down do
    drop constraint(@updates, :bl_jee_form_updates_academic_year_format_check)

    create constraint(@updates, :bl_jee_form_updates_academic_year_check,
             check: @previous_academic_year_check
           )

    drop constraint(@updates, :bl_jee_form_updates_reasons_unique_check)

    execute("DROP FUNCTION blended_learning_array_has_no_duplicates(anyarray)")
  end
end
