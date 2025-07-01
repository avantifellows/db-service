defmodule Dbservice.Repo.Migrations.CreateColleges do
  use Ecto.Migration

  def change do
    create table(:colleges, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :college_id, :string, null: false
      add :institute, :string, null: false
      add :state, :string
      add :place, :string
      add :dist_code, :string
      add :co_ed, :boolean, default: false
      add :college_type, :string
      add :year_established, :integer
      add :affiliated_to, :string
      add :tuition_fee, :decimal
      add :af_hierarchy, :string
      add :college_ranking, :integer
      add :management_type, :string
      add :expected_salary, :decimal
      add :salary_tier, :string
      add :qualifying_exam, :string
      add :top_200_nirf, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:colleges, [:college_id], name: :colleges_college_id_index)
    create index(:colleges, [:state, :district_code])
  end
end
