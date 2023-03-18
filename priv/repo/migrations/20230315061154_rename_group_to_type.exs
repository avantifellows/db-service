defmodule Dbservice.Repo.Migrations.RenameGroupToType do
  use Ecto.Migration

  def change do
    rename table(:group), to: table(:group_type)
  end
end
