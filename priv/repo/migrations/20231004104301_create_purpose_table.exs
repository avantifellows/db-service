defmodule Dbservice.Repo.Migrations.CreatePurposeTable do
  use Ecto.Migration

  def change do
    create table(:purpose) do
      add(:name, :string)
      add(:description, :text)
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
