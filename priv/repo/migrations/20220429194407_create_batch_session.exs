defmodule Dbservice.Repo.Migrations.CreateBatchSession do
  use Ecto.Migration

  def change do
    create table(:batch_session, primary_key: false) do
      add :batch_id, references(:batch, on_delete: :nothing)
      add :session_id, references(:session, on_delete: :nothing)
    end

    create index(:batch_session, [:batch_id])
    create index(:batch_session, [:session_id])
  end
end
