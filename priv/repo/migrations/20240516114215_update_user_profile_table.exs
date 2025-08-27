defmodule Dbservice.Repo.Migrations.UpdateUserProfileTable do
  use Ecto.Migration

  def change do
    alter table(:user_profile) do
      remove :current_batch
      remove :current_program
      remove :current_grade
    end
  end
end
