defmodule Dbservice.Repo.Migrations.CreateDemographicProfileTable do
  use Ecto.Migration

  def change do
    create table(:demographic_profile) do
      add :category, :string
      add :gender, :string
      add :caste, :string
      add :physically_handicapped, :boolean
      add :family_income, :string
      add :religion, :string
      add :defence_ward, :string
      add :nationality, :string
      add :ews_ward, :string
      add :language, :string
      add :urban_rural, :boolean
      add :region, :string

      timestamps()
    end

    create index(:demographic_profile, [:category])
  end
end
