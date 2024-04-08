defmodule Dbservice.Repo.Migrations.AlterUserProfile do
  use Ecto.Migration

  def change do
    alter table(:user_profile) do
      remove :full_name
      remove :email
      remove :date_of_birth
      remove :gender
      remove :role
      remove :state
      remove :country
      remove :first_session_accessed
    end
  end
end
