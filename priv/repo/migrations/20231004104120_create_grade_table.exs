defmodule Dbservice.Repo.Migrations.CreateGradeTable do
  use Ecto.Migration

  def change do
    create table(:grade) do
      add(:number, :integer)
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
