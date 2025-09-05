defmodule Dbservice.Repo.Migrations.ChangeUrbanRuralToBooleanInDemographicProfile do
  use Ecto.Migration

  def up do
    # Add a temporary boolean column
    alter table(:demographic_profile) do
      add :urban_rural_temp, :boolean, default: false
    end

    # Update the temporary column based on the string values
    execute """
    UPDATE demographic_profile
    SET urban_rural_temp = CASE
      WHEN LOWER(urban_rural) IN ('urban', 'true', '1', 'yes') THEN true
      WHEN LOWER(urban_rural) IN ('rural', 'false', '0', 'no') THEN false
      ELSE false
    END
    """

    # Drop the old column and rename the temporary one
    alter table(:demographic_profile) do
      remove :urban_rural
    end

    alter table(:demographic_profile) do
      add :urban_rural, :boolean, default: false
    end

    # Copy data from temp column to the new boolean column
    execute "UPDATE demographic_profile SET urban_rural = urban_rural_temp"

    # Drop the temporary column
    alter table(:demographic_profile) do
      remove :urban_rural_temp
    end
  end

  def down do
    # Revert back to string type
    alter table(:demographic_profile) do
      add :urban_rural_temp, :string
    end

    execute """
    UPDATE demographic_profile
    SET urban_rural_temp = CASE
      WHEN urban_rural = true THEN 'urban'
      ELSE 'rural'
    END
    """

    alter table(:demographic_profile) do
      remove :urban_rural
    end

    alter table(:demographic_profile) do
      add :urban_rural, :string
    end

    execute "UPDATE demographic_profile SET urban_rural = urban_rural_temp"

    alter table(:demographic_profile) do
      remove :urban_rural_temp
    end
  end
end
