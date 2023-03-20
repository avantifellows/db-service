defmodule Dbservice.Repo.Migrations.RemoveUserIdFromUserSession do
  use Ecto.Migration

  def change do
    alter table("user_session") do
      remove :user_id
      add :is_user_valid, :boolean, default: false
    end
  end
end
