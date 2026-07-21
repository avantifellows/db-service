defmodule Dbservice.Repo.Migrations.CreateCentreBatch do
  use Ecto.Migration

  def change do
    create table(:centre_batch) do
      add :centre_id, references(:centres, on_delete: :nothing), null: false
      add :batch_id, references(:batch, on_delete: :nothing), null: false
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:centre_batch, [:centre_id])
    create index(:centre_batch, [:batch_id])

    # A batch is linked to a centre at most once while the link is live.
    # Soft-deleted history rows are exempt, so a link can be removed and
    # re-created without tripping the constraint.
    create unique_index(:centre_batch, [:centre_id, :batch_id],
             where: "deleted_at IS NULL",
             name: :centre_batch_active_link_unique
           )
  end
end
