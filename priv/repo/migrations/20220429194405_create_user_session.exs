defmodule Dbservice.Repo.Migrations.CreateUserSession do
  use Ecto.Migration

  def change do
    create table(:user_session) do
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :data, :map
      add :user_id, references(:user, on_delete: :nothing)
      add :session_occurence_id, references(:session_occurence, on_delete: :nothing)

      timestamps()
    end

    create index(:user_session, [:user_id])
    create index(:user_session, [:session_occurence_id])
  end
end
