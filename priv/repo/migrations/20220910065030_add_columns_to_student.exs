defmodule Dbservice.Repo.Migrations.AddColumnsToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :physically_handicapped, :boolean
      add :cohort, :string
      add :family_income, :string
      add :father_profession, :string
      add :father_education_level, :string
      add :mother_profession, :string
      add :mother_education_level, :string
      add :time_of_device_availability, :date
      add :has_internet_access, :boolean
      add :primary_smartphone_owner, :string
      add :primary_smartphone_owner_profession, :string
    end

  end
end
