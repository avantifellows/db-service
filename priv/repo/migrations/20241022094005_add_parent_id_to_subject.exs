defmodule Dbservice.Repo.Migrations.AddParentIdToSubject do
  use Ecto.Migration

  def change do
    alter table(:subject) do
      add :parent_id, references(:subject, on_delete: :nilify_all)
    end
  end
end
