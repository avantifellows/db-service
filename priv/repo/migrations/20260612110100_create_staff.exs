defmodule Dbservice.Repo.Migrations.CreateStaff do
  use Ecto.Migration

  def change do
    # Non-teaching AF staff (program managers, APCs, future ops roles).
    # Teachers remain fully modelled by the teacher table.
    create table(:staff) do
      add :user_id, references(:user, on_delete: :nothing), null: false
      add :employee_code, :string, null: false
      add :staff_type, :string, null: false
      add :designation, :string
      add :exit_date, :date

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:staff, [:employee_code])
    # One non-teaching employment record per person.
    create unique_index(:staff, [:user_id])
    create index(:staff, [:staff_type])
  end
end
