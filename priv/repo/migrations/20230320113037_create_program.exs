defmodule Dbservice.Repo.Migrations.CreateProgram do
  use Ecto.Migration

  def change do
    create table(:program) do
      add :name, :string
      add :type, :string
      add :sub_type, :string
      add :mode, :string
      add :start_date, :date
      add :target_outreach, :integer
      add :product_used, :string
      add :donor, :string
      add :state, :string
      add :model, :string
      add :group_id, references(:group, on_delete: :nothing)

      timestamps()
    end
  end
end
