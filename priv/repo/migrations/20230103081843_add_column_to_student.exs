defmodule Dbservice.Repo.Migrations.AddColumnToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :is_dropper, :boolean
      add :contact_hours_per_week, :integer
    end
  end
end
