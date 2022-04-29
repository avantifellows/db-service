defmodule Dbservice.Repo.Migrations.CreateSessionOccurence do
  use Ecto.Migration

  def change do
    create table(:session_occurence) do
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :session_id, references(:session, on_delete: :nothing)

      timestamps()
    end

    create index(:session_occurence, [:session_id])
  end
end
