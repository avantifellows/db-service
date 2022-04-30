defmodule Dbservice.Repo.Migrations.CreateBatchSession do
  use Ecto.Migration

  def change do
    create table(:batch_session) do
      add :user_id, references(:user, on_delete: :nothing)
      add :session_id, references(:session, on_delete: :nothing)

      timestamps()
    end

    create index(:batch_session, [:user_id])
    create index(:batch_session, [:session_id])
  end
end
