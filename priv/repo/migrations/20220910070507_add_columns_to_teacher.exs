defmodule Dbservice.Repo.Migrations.AddColumnsToTeacher do
  use Ecto.Migration

  def change do
    alter table(:teacher) do
      add :uuid, :string
    end
  end
end
