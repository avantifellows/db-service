defmodule Dbservice.Repo.Migrations.CreateSubjectTable do
  use Ecto.Migration

  def change do
    create table(:subject) do
      add(:name, :string)
      add(:code, :string)
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
