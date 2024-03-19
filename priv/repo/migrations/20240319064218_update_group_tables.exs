defmodule Dbservice.Repo.Migrations.UpdateGroupTables do
  use Ecto.Migration

  def change do
    rename table("group"), to: table("auth_group")
    rename table("group_type"), to: table("group")
  end
end
