defmodule Dbservice.Repo.Migrations.AlterUserSessionTable do
  use Ecto.Migration

  def change do
    rename table("user_session"), :start_time, to: :timestamp

    alter table("user_session") do
      remove :end_time
      remove :is_user_valid
    end
  end
end
