defmodule Dbservice.Repo.Migrations.CreateCmsPermission do
  use Ecto.Migration

  def up do
    create table(:cms_permission) do
      add :email, :string, null: false
      add :role, :string, null: false, default: "viewer"

      timestamps()
    end

    create unique_index(:cms_permission, [:email])
  end

  def down do
    drop table(:cms_permission)
  end
end
