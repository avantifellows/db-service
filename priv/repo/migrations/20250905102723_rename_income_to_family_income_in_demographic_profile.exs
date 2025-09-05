defmodule Dbservice.Repo.Migrations.RenameIncomeToFamilyIncomeInDemographicProfile do
  use Ecto.Migration

  def change do
    rename table(:demographic_profile), :income, to: :family_income
  end
end
