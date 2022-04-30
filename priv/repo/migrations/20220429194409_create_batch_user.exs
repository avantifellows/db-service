defmodule Dbservice.Repo.Migrations.CreateBatchUser do
  use Ecto.Migration

  def change do
    create table(:batch_user) do
      add :batch_id, references(:batch, on_delete: :nothing)
      add :user_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:batch_user, [:batch_id])
    create index(:batch_user, [:user_id])
  end
end
