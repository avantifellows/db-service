defmodule Dbservice.Repo.Migrations.CreateCollege do
  use Ecto.Migration

  def change do
    create table(:college) do
      add :college_id, :string, null: false
      add :name, :string, null: false
      add :state, :string
      add :address, :string
      add :district_code, :string
      add :gender_type, :string
      add :college_type, :string
      add :management_type, :string
      add :year_established, :integer
      add :affiliated_to, :string
      add :tuition_fee, :decimal
      add :af_hierarchy, :decimal
      add :expected_salary, :decimal
      add :salary_tier, :string
      add :qualifying_exam, :string
      add :nirf_ranking, :integer
      add :top_200_nirf, :boolean

      timestamps()
    end

    create unique_index(:college, [:college_id])
  end
end
