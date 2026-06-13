defmodule Dbservice.Repo.Migrations.CreateCentrePositions do
  use Ecto.Migration

  def change do
    create table(:centre_positions) do
      add :centre_id, references(:centres, on_delete: :nothing), null: false
      add :role, :string, null: false
      add :user_id, references(:user, on_delete: :nothing)
      add :hr_code, :string
      add :notes, :text
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:centre_positions, [:centre_id])
    create index(:centre_positions, [:user_id])

    # A person can hold at most one ACTIVE seat per (centre, role). Vacant
    # seats (user_id NULL) and soft-deleted history rows are exempt, so a
    # centre may carry several open vacancies for the same role.
    create unique_index(:centre_positions, [:centre_id, :role, :user_id],
             where: "deleted_at IS NULL AND user_id IS NOT NULL",
             name: :centre_positions_active_assignment_unique
           )
  end
end
