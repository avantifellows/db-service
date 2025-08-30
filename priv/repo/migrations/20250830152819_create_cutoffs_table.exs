defmodule Dbservice.Repo.Migrations.CreateCutoffsTable do
  use Ecto.Migration

  def change do
    create table(:cutoffs) do
      add :cutoff_year, :integer
      add :exam_occurrence_id, references(:exam_occurrence, on_delete: :nothing)
      add :college_id, references(:college, on_delete: :nothing)
      add :degree, :string
      add :branch_id, references(:branch, on_delete: :nothing)
      add :category_id, :integer
      add :state_quota, :string
      add :opening_rank, :integer
      add :closing_rank, :integer

      timestamps()
    end

    create index(:cutoffs, [:exam_occurrence_id])
    create index(:cutoffs, [:college_id])
    create index(:cutoffs, [:branch_id])
    create index(:cutoffs, [:category_id])
    create index(:cutoffs, [:cutoff_year])
    create index(:cutoffs, [:degree])
    create index(:cutoffs, [:state_quota])
  end
end
