defmodule Dbservice.Repo.Migrations.AlterCollegeTable do
  use Ecto.Migration

  def change do
    alter table(:college) do
      add :placement_rate, :float
      add :median_salary, :float
      add :entrance_test, {:array, :integer}
      add :tuition_fees_annual, :float
    end
  end
end
