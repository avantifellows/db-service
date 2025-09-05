defmodule Dbservice.Repo.Migrations.ChangePwdToPhysicallyHandicappedInDemographicProfile do
  use Ecto.Migration

  def change do
    alter table(:demographic_profile) do
      remove :pwd
      add :physically_handicapped, :boolean, default: false
    end
  end
end
