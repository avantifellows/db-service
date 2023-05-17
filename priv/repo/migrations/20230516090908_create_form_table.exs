defmodule Dbservice.Repo.Migrations.CreateFormTable do
  use Ecto.Migration

  def change do
    create table(:form_schema) do
      add :name, :string
      add :attributes, :map

      timestamps()
    end
  end
end
