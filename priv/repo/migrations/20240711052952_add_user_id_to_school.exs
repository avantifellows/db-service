defmodule Dbservice.Repo.Migrations.AddUserIdToSchool do
  use Ecto.Migration

  def change do
    alter table(:school) do
      add :user_id, references(:user, on_delete: :nothing)
    end
  end
end
