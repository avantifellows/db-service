defmodule Dbservice.Repo.Migrations.RemoveTagIdFromSubject do
  use Ecto.Migration

  def up do
    alter table(:subject) do
      remove :tag_id
    end
  end

  def down do
    alter table(:subject) do
      add :tag_id, references(:tag, on_delete: :nothing)
    end
  end
end
