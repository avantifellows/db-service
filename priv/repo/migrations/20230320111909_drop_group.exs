defmodule Dbservice.Repo.Migrations.DropGroup do
  use Ecto.Migration

  def change do
    drop table("group")
  end
end
