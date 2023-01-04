defmodule Dbservice.Repo.Migrations.AddColumnToUser do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :country, :string
    end
  end
end
