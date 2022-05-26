defmodule Dbservice.Repo.Migrations.CreateBatchUser do
  use Ecto.Migration

  def change do
    create table(:batch_user, primary_key: false) do
      add :batch_id, references(:batch, on_delete: :nothing)
      add :user_id, references(:user, on_delete: :nothing)
    end

    create index(:batch_user, [:batch_id])
    create index(:batch_user, [:user_id])
  end
end
