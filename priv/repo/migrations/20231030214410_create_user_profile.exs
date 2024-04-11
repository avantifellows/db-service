defmodule Dbservice.Repo.Migrations.CreateUserProfile do
  use Ecto.Migration

  def change do
    create table(:user_profile) do
      add :current_grade, :string
      add :current_program, :string
      add :current_batch, :string
      add :logged_in_atleast_once, :boolean
      add :latest_session_accessed, :string
      add :user_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:user_profile, [:user_id])
  end
end
