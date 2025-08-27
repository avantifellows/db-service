defmodule Dbservice.Repo.Migrations.CreateCandidate do
  use Ecto.Migration

  def change do
    create table(:candidate) do
      add :degree, :string
      add :college_name, :string
      add :branch_name, :string
      add :latest_cgpa, :decimal, precision: 3, scale: 2
      add :subject_id, references(:subject, on_delete: :nothing)
      add :candidate_id, :string
      add :user_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:candidate, [:user_id])
    create index(:candidate, [:subject_id])
    create index(:candidate, [:candidate_id])
  end
end
