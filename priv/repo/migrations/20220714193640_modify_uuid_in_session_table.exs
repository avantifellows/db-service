defmodule Dbservice.Repo.Migrations.ModifyUuidInSessionTable do
  use Ecto.Migration

  def change do
    alter table("session") do
      remove :uuid
    end

    alter table("session") do
      add :uuid, :uuid, default: fragment("uuid_generate_v4()")
    end
  end
end
