defmodule Dbservice.Repo.Migrations.ChangeCategoryToStringInDemographicProfile do
  use Ecto.Migration

  def up do
    alter table(:demographic_profile) do
      modify :category, :string
    end
  end

  def down do
    alter table(:demographic_profile) do
      modify :category, :integer
    end
  end
end
