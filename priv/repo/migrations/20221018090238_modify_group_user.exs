defmodule Dbservice.Repo.Migrations.ModifyGroupUser do
  use Ecto.Migration

  def change do
    alter table(:group_user) do
      modify :inserted_at, :utc_datetime, default: fragment("NOW()")
      modify :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
