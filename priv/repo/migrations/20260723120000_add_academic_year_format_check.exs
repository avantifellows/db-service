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
    # Fail loudly if any existing row violates the format (bad shape or
    # non-consecutive years) instead of silently skipping them — resolve those
    # rows first, then re-run.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM enrollment_record
        WHERE academic_year IS NOT NULL
          AND NOT (#{@valid_predicate})
      ) THEN
        RAISE EXCEPTION 'enrollment_record.academic_year has values that are not a consecutive-year YYYY-YYYY range; resolve before adding constraint';
      END IF;
    END $$;
    """)

    # Idempotent re-run (no enclosing transaction to roll back a partial run).
    execute("ALTER TABLE enrollment_record DROP CONSTRAINT IF EXISTS #{@constraint}")

    execute("""
    ALTER TABLE enrollment_record
    ADD CONSTRAINT #{@constraint}
    CHECK (#{@valid_predicate})
    NOT VALID
    """)

    execute("ALTER TABLE enrollment_record VALIDATE CONSTRAINT #{@constraint}")
  end

  def down do
    execute("ALTER TABLE enrollment_record DROP CONSTRAINT IF EXISTS #{@constraint}")
  end
end
