defmodule Dbservice.Repo.Migrations.ModifyUuidInSession do
  use Ecto.Migration

  def change do
    alter table("session") do
      remove :uuid
    end

    alter table("session") do
      add :uuid, :string
    end
  end
end
