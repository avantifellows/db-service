defmodule Dbservice.Repo.Migrations.AddAcademicYearFormatCheck do
  use Ecto.Migration

  # Enforces the canonical YYYY-YYYY academic year on enrollment_record, rejecting
  # short forms like "2026-27" that leaked in via imports. NULL is allowed because
  # auth_group enrollment records legitimately carry no academic year.
  def up do
    # Fail loudly if any malformed rows remain, rather than silently skipping them or
    # adding a constraint that can't validate. Resolve those rows first, then re-run.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM enrollment_record
        WHERE academic_year IS NOT NULL
          AND academic_year !~ '^[0-9]{4}-[0-9]{4}$'
      ) THEN
        RAISE EXCEPTION 'enrollment_record.academic_year has values not in YYYY-YYYY format; resolve before adding constraint';
      END IF;
    END $$;
    """)

    execute("""
    ALTER TABLE enrollment_record
    ADD CONSTRAINT enrollment_record_academic_year_format
    CHECK (academic_year IS NULL OR academic_year ~ '^[0-9]{4}-[0-9]{4}$')
    """)
  end

  def down do
    execute("""
    ALTER TABLE enrollment_record
    DROP CONSTRAINT IF EXISTS enrollment_record_academic_year_format
    """)
  end
end
