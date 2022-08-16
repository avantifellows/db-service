defmodule Dbservice.Repo.Migrations.AddColumnsToBatch do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :program_id, references(:program, on_delete: :nothing)
      add :contact_hours_per_week, :integer
    end

    create index(:batch, [:program_id])
  end
end
