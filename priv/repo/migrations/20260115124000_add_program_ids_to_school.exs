defmodule Dbservice.Repo.Migrations.AddProgramIdsToSchool do
  use Ecto.Migration

  def up do
    # Step 1: Add program_ids column to school table
    alter table(:school) do
      add :program_ids, {:array, :integer}, default: []
    end

    # Step 2: Assign NVS (program_id = 64) to all JNV schools except excluded ones
    # Excluded UDISE codes: 29270124102, 29230607302, 29240101004, 29160100508,
    #                       36020990151, 36130300529, 27090802602, 27080812802
    execute """
    UPDATE school
    SET program_ids = ARRAY[64]
    WHERE af_school_category = 'JNV'
      AND udise_code NOT IN (
        '29270124102', '29230607302', '29240101004', '29160100508',
        '36020990151', '36130300529', '27090802602', '27080812802'
      )
    """

    # Step 3: Add CoE (program_id = 1) to CoE schools
    # 18 schools: 14061, 14201, 19061, 19175, 24701, 34054, 34082, 39241, 39370,
    #             49037, 54059, 59204, 59324, 59525, 59526, 74034, 79012, 79019
    execute """
    UPDATE school
    SET program_ids = array_cat(ARRAY[1], program_ids)
    WHERE code IN (
      '14061', '14201', '19061', '19175', '24701', '34054', '34082', '39241', '39370',
      '49037', '54059', '59204', '59324', '59525', '59526', '74034', '79012', '79019'
    )
    """

    # Step 4: Add Nodal (program_id = 2) to Nodal schools (2025-26)
    # 13 schools: 14032, 34056, 34062, 34068, 49022, 49037, 49046, 49057, 49069,
    #             59525, 59528, 69035, 69058
    execute """
    UPDATE school
    SET program_ids = array_cat(ARRAY[2], program_ids)
    WHERE code IN (
      '14032', '34056', '34062', '34068', '49022', '49037', '49046', '49057', '49069',
      '59525', '59528', '69035', '69058'
    )
    """

    # Create GIN index for efficient array queries (optional, for performance)
    create index(:school, [:program_ids], using: :gin)
  end

  def down do
    drop index(:school, [:program_ids])

    alter table(:school) do
      remove :program_ids
    end
  end
end
