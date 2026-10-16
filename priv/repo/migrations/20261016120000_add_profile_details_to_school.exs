defmodule Dbservice.Repo.Migrations.AddProfileDetailsToSchool do
  use Ecto.Migration

  @support_statuses "'Supportive', 'Non-Supportive', 'Neutral'"
  @residential_statuses "'Residential', 'Non-Residential'"
  @grades 6..12

  def up do
    # `school` holds what identifies a school - code, UDISE, where it is, which
    # board. It holds nothing about how to reach it or how well the engagement
    # is going, so a field visit's findings live in someone's sheet. These
    # columns bring that onto the record itself.
    #
    # Every column is nullable, including the three grade flags: a school we
    # have not surveyed yet is not a school without Grades 6-8, and a boolean
    # defaulting to false would erase that difference on the whole table the
    # moment it is added. NULL means "not asked yet", false means "asked, and
    # it does not offer them".
    #
    # Adding nullable columns with no default is metadata-only, so this does
    # not scan the table. The CHECK constraints below do scan it, but every new
    # column is NULL so the scan cannot fail and the migration stays in one
    # transaction.
    alter table(:school) do
      add :school_email, :string, size: 255
      add :principal_incharge_name, :string, size: 100
      add :principal_incharge_contact, :string, size: 15
      add :pmu_coordinator_name, :string, size: 100
      add :pmu_coordinator_contact, :string, size: 15
      add :school_support_status, :string, size: 15
      add :school_residential_status, :string, size: 20
      add :has_grades_6_to_8, :boolean
      add :has_grades_9_to_10, :boolean
      add :has_grades_11_to_12, :boolean

      # One column per grade rather than a JSON map: the estimate is filled in
      # from a sheet and read back by analytics, and both want a plain integer
      # column. Grades 6 to 12 are the span the availability flags above cover.
      for grade <- @grades do
        add :"estimated_strength_grade_#{grade}", :integer
      end

      # Free text, so `:text` rather than a capped varchar - a remark that runs
      # long should be stored, not truncated or rejected.
      add :school_notes, :text
    end

    # One ALTER for every constraint, so `school` is scanned once rather than
    # nine times, and a bounded lock_timeout so this queues behind live traffic
    # instead of blocking it. SET LOCAL is scoped to the migration transaction.
    execute("SET LOCAL lock_timeout = '5s'")

    strength_checks =
      @grades
      |> Enum.map_join(
        " AND\n          ",
        &"(estimated_strength_grade_#{&1} IS NULL OR estimated_strength_grade_#{&1} >= 0)"
      )

    execute("""
    ALTER TABLE school
      ADD CONSTRAINT school_support_status_check
        CHECK (school_support_status IS NULL OR
               school_support_status IN (#{@support_statuses})),
      ADD CONSTRAINT school_residential_status_check
        CHECK (school_residential_status IS NULL OR
               school_residential_status IN (#{@residential_statuses})),
      ADD CONSTRAINT school_estimated_strength_check
        CHECK (
          #{strength_checks}
        )
    """)
  end

  def down do
    drop constraint(:school, :school_estimated_strength_check)
    drop constraint(:school, :school_residential_status_check)
    drop constraint(:school, :school_support_status_check)

    alter table(:school) do
      remove :school_notes

      for grade <- @grades do
        remove :"estimated_strength_grade_#{grade}"
      end

      remove :has_grades_11_to_12
      remove :has_grades_9_to_10
      remove :has_grades_6_to_8
      remove :school_residential_status
      remove :school_support_status
      remove :pmu_coordinator_contact
      remove :pmu_coordinator_name
      remove :principal_incharge_contact
      remove :principal_incharge_name
      remove :school_email
    end
  end
end
