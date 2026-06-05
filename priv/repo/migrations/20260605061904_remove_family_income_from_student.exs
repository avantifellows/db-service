defmodule Dbservice.Repo.Migrations.RemoveFamilyIncomeFromStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      # Consolidated onto annual_family_income; family_income is no longer used.
      # Typed remove keeps the migration reversible (rollback re-adds the column).
      remove :family_income, :string
    end
  end
end
