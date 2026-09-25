defmodule Dbservice.Repo.Migrations.AddUniformSizesAndG10SchoolToStudent do
  use Ecto.Migration

  @sizes "'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'"

  def up do
    # All five columns are nullable so the data team can backfill the Grade 10
    # fields for the students it has already matched while teachers collect the
    # rest. Adding a nullable column with no default is metadata-only; the CHECK
    # constraints below scan the table, but every new column is NULL so the scan
    # cannot fail and the migration stays in one transaction.
    alter table(:student) do
      add :tshirt_size, :string, size: 4
      add :track_pant_size, :string, size: 4
      add :g10_school_state, :string, size: 50
      add :g10_school_name, :string, size: 150
      # varchar, not an integer type, so leading zeros survive.
      add :g10_school_udise_code, :string, size: 11
    end

    create constraint(:student, :student_tshirt_size_check,
             check: "tshirt_size IS NULL OR tshirt_size IN (#{@sizes})"
           )

    create constraint(:student, :student_track_pant_size_check,
             check: "track_pant_size IS NULL OR track_pant_size IN (#{@sizes})"
           )

    create constraint(:student, :student_g10_school_udise_code_check,
             check: "g10_school_udise_code IS NULL OR g10_school_udise_code ~ '^[0-9]{11}$'"
           )
  end

  def down do
    drop constraint(:student, :student_g10_school_udise_code_check)
    drop constraint(:student, :student_track_pant_size_check)
    drop constraint(:student, :student_tshirt_size_check)

    alter table(:student) do
      remove :g10_school_udise_code
      remove :g10_school_name
      remove :g10_school_state
      remove :track_pant_size
      remove :tshirt_size
    end
  end
end
