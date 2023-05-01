defmodule Dbservice.Repo.Migrations.CreateSchool do
  use Ecto.Migration

  def change do
    create table(:school) do
      add :code, :string
      add :name, :string
      add :medium, :string

      timestamps()
    end
  end
end
