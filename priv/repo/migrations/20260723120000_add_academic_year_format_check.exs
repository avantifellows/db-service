defmodule Dbservice.Repo.Migrations.AddAcademicYearFormatCheck do
  use Ecto.Migration

  # Run outside a single DDL transaction so ADD CONSTRAINT ... NOT VALID and
  # VALIDATE CONSTRAINT commit separately: a plain `ADD CONSTRAINT ... CHECK`
  # holds ACCESS EXCLUSIVE while it scans the whole table, blocking every
  # enrollment_record write behind it. NOT VALID adds the constraint with only a
  # brief lock (no scan); VALIDATE then scans under SHARE UPDATE EXCLUSIVE, which
  # does not block writes. In one transaction the NOT VALID lock would be held
  # until commit (through the scan), defeating the point — hence separate
  # transactions.
  @disable_ddl_transaction true

  @constraint "enrollment_record_academic_year_format"

  # Canonical academic year: NULL (auth_group records carry none) or a YYYY-YYYY
  # range of two consecutive years (e.g. 2026-2027). The CASE guards the ::int
  # casts so they only run on shape-valid values.
  @valid_predicate """
  academic_year IS NULL
  OR CASE
       WHEN academic_year ~ '^[0-9]{4}-[0-9]{4}$'
       THEN left(academic_year, 4)::int + 1 = right(academic_year, 4)::int
       ELSE false
     END
  """

  def up do
    # Auto-normalize the safe short form "YYYY-YY" -> "YYYY-YYYY" (e.g. "2026-27"
    # -> "2026-2027"), but only when the two-digit suffix is exactly start_year + 1
    # so the conversion is unambiguous (handles century rollover via % 100). This
    # heals the common import artifact in place, without a manual data step or an
    # aborted deploy.
    execute("""
    UPDATE enrollment_record
    SET academic_year = left(academic_year, 4) || '-' || (left(academic_year, 4)::int + 1)::text
    WHERE academic_year ~ '^[0-9]{4}-[0-9]{2}$'
      AND right(academic_year, 2)::int = (left(academic_year, 4)::int + 1) % 100
    """)

    # Add the constraint NOT VALID (brief lock, no scan) so every FUTURE write is
    # enforced immediately. Idempotent re-run (no enclosing transaction to roll
    # back a partial run).
    execute("ALTER TABLE enrollment_record DROP CONSTRAINT IF EXISTS #{@constraint}")

    execute("""
    ALTER TABLE enrollment_record
    ADD CONSTRAINT #{@constraint}
    CHECK (#{@valid_predicate})
    NOT VALID
    """)

    # VALIDATE existing rows only when they are all clean; otherwise leave the
    # constraint NOT VALID and WARN (not RAISE) so the deploy never aborts. Any
    # values that could not be auto-fixed — genuinely non-consecutive ranges like
    # "2025-2027", mismatched short forms, other junk — need a human decision;
    # fix them by hand later and run `VALIDATE CONSTRAINT`. New/updated rows are
    # already protected by the NOT VALID constraint.
    execute("""
    DO $$
    DECLARE
      invalid_count integer;
    BEGIN
      SELECT count(*) INTO invalid_count
      FROM enrollment_record
      WHERE academic_year IS NOT NULL
        AND NOT (#{@valid_predicate});

      IF invalid_count = 0 THEN
        ALTER TABLE enrollment_record VALIDATE CONSTRAINT #{@constraint};
      ELSE
        RAISE WARNING 'enrollment_record.academic_year: % row(s) are not a consecutive-year YYYY-YYYY range and were left as-is; the constraint was added NOT VALID so it guards new writes. Resolve the remaining rows and run: ALTER TABLE enrollment_record VALIDATE CONSTRAINT %;', invalid_count, '#{@constraint}';
      END IF;
    END $$;
    """)
  end

  def down do
    execute("ALTER TABLE enrollment_record DROP CONSTRAINT IF EXISTS #{@constraint}")
  end
end
