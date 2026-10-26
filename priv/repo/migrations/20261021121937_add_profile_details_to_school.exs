defmodule Dbservice.Repo.Migrations.AddProfileDetailsToSchool do
  use Ecto.Migration

  @support_statuses "'Supportive', 'Non-Supportive', 'Neutral'"
  @residential_statuses "'Residential', 'Non-Residential'"
  @streams "'Science', 'Commerce', 'Arts (Humanities)'"
  # Only the two grades the programs actually size for. The other grades are
  # recorded as offered or not in `grades_offered`; nobody estimates their
  # strength, and a column nobody fills reads as "none" to anyone querying it.
  @strength_grades 11..12

  def up do
    # `school` holds what identifies a school - code, UDISE, where it is, which
    # board. It holds nothing about how to reach it or how well the engagement
    # is going, so a field visit's findings live in someone's sheet. These
    # columns bring that onto the record itself.
    #
    # Every column is nullable: a school we have not surveyed yet is not a
    # school with no grades and no coordinator, and a default would erase that
    # difference on the whole table the moment it is added.
    #
    # Adding nullable columns with no default is metadata-only, so this does
    # not scan the table. The CHECK constraints below do scan it, but every new
    # column is NULL so the scan cannot fail and the migration stays in one
    # transaction.
    #
    # A bounded lock_timeout, set first so it covers both the ALTER TABLE
    # below and the CHECK constraints after it: each queues behind live
    # traffic instead of blocking it. SET LOCAL is scoped to the migration
    # transaction.
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:school) do
      add(:school_email, :string, size: 255)
      add(:principal_incharge_name, :string, size: 100)
      add(:principal_incharge_contact, :string, size: 15)
      add(:pmu_coordinator_name, :string, size: 100)
      add(:pmu_coordinator_contact, :string, size: 15)
      add(:school_support_status, :string, size: 15)
      add(:school_residential_status, :string, size: 20)

      # The grades the school runs, as an integer array rather than one flag per
      # grade band: ops fills a single comma-separated cell, and an array stays
      # queryable - `6 = ANY(grades_offered)` - where a comma-separated string
      # would need a LIKE that matches "1" inside "11". `program_ids` on this
      # same table is already stored this way.
      #
      # No default: NULL is "not surveyed yet", and an empty array is a surveyed
      # school that runs none of these grades. A default of {} would erase that
      # difference across the whole table the moment the column lands.
      add(:grades_offered, {:array, :integer})

      # The streams the school runs at senior secondary, same shape and same
      # reasoning as `grades_offered` - a school commonly runs more than one.
      add(:school_stream, {:array, :string})

      # One column per grade rather than a JSON map: the estimate is filled in
      # from a sheet and read back by analytics, and both want a plain integer
      # column.
      for grade <- @strength_grades do
        add(:"estimated_strength_grade_#{grade}", :integer)
      end

      # Free text, so `:text` rather than a capped varchar - a remark that runs
      # long should be stored, not truncated or rejected.
      add(:school_notes, :text)
    end

    # One ALTER for every constraint, so `school` is scanned once rather than
    # several times.
    strength_checks =
      @strength_grades
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
        ),
      ADD CONSTRAINT school_grades_offered_check
        CHECK (
          -- Containment rather than a subquery, which a CHECK may not hold. It
          -- also rejects a NULL element: ARRAY[NULL] <@ ARRAY[1..12] is false.
          -- Duplicates are deduped by the changeset rather than rejected here.
          grades_offered IS NULL OR
          grades_offered <@ ARRAY[1,2,3,4,5,6,7,8,9,10,11,12]
        ),
      ADD CONSTRAINT school_stream_check
        CHECK (
          school_stream IS NULL OR
          school_stream <@ ARRAY[#{@streams}]::varchar[]
        )
    """)
  end

  def down do
    drop(constraint(:school, :school_stream_check))
    drop(constraint(:school, :school_grades_offered_check))
    drop(constraint(:school, :school_estimated_strength_check))
    drop(constraint(:school, :school_residential_status_check))
    drop(constraint(:school, :school_support_status_check))

    alter table(:school) do
      remove(:school_notes)

      for grade <- @strength_grades do
        remove(:"estimated_strength_grade_#{grade}")
      end

      remove(:school_stream)
      remove(:grades_offered)
      remove(:school_residential_status)
      remove(:school_support_status)
      remove(:pmu_coordinator_contact)
      remove(:pmu_coordinator_name)
      remove(:principal_incharge_contact)
      remove(:principal_incharge_name)
      remove(:school_email)
    end
  end
end
