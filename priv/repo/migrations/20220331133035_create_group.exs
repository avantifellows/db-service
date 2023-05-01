defmodule Dbservice.Repo.Migrations.CreateGroup do
  use Ecto.Migration

  def change do
    create table(:group) do
      add :input_schema, :map
      add :locale, :string
      add :locale_data, :map

      timestamps()
    end
  end
end
