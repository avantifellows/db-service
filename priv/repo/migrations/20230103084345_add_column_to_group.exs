defmodule Dbservice.Repo.Migrations.AddColumnToGroup do
  use Ecto.Migration

  def change do
    alter table(:group) do
      add :program_model, :string
    end
  end
end
