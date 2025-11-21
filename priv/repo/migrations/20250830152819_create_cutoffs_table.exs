defmodule Dbservice.Repo.Migrations.CreateCutoffsTable do
  use Ecto.Migration

  def change do
    create table(:cutoffs) do
      add :cutoff_year, :integer
      add :exam_occurrence_id, references(:exam_occurrence, on_delete: :nothing)
      add :college_id, references(:college, on_delete: :nothing)
      add :degree, :string
      add :branch_id, references(:branch, on_delete: :nothing)
      add :demographic_profile_id, references(:demographic_profile, on_delete: :nothing)
      add :state_quota, :string
      add :opening_rank, :integer
      add :closing_rank, :integer

      timestamps()
    end

    create index(:cutoffs, [:exam_occurrence_id])
  end
end
