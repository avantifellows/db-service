defmodule Dbservice.Repo.Migrations.CreateUserProfile do
  use Ecto.Migration

  def change do
    create table(:user_profile) do
      add :full_name, :string
      add :email, :string
      add :date_of_birth, :date
      add :gender, :string
      add :role, :string
      add :state, :string
      add :country, :string
      add :current_grade, :string
      add :current_program, :string
      add :current_batch, :string
      add :logged_in_atleast_once, :boolean
      add :first_session_accessed, :string
      add :latest_session_accessed, :string
      add :user_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:user_profile, [:user_id])
  end
end
