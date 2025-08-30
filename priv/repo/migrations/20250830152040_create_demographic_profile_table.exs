defmodule Dbservice.Repo.Migrations.CreateDemographicProfileTable do
  use Ecto.Migration

  def change do
    create table(:demographic_profile) do
      add :category_id, :integer
      add :gender, :string
      add :caste, :string
      add :pwd, :string
      add :income, :string
      add :religion, :string
      add :defence_ward, :string
      add :nationality, :string
      add :ews_ward, :string
      add :language, :string
      add :urban_rural, :string
      add :region, :string

      timestamps()
    end

    create index(:demographic_profile, [:category_id])
    create index(:demographic_profile, [:gender])
    create index(:demographic_profile, [:caste])
  end
end
