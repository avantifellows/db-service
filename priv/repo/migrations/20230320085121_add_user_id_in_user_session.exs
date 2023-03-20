defmodule Dbservice.Repo.Migrations.AddUserIdInUserSession do
  use Ecto.Migration

  def change do
    alter table("user_session") do
      add :user_id, :string
    end
  end
end
