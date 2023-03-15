defmodule Dbservice.Repo.Migrations.RenameGroupToType do
  use Ecto.Migration

  def change do
    rename table(:group), to: table(:type)
  end
end
