defmodule Dbservice.Repo.Migrations.ModifyGroupSession do
  use Ecto.Migration

  def change do
    alter table(:group_session) do
      modify :inserted_at, :utc_datetime, default: fragment("NOW()")
      modify :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
