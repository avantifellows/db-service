defmodule Dbservice.Repo.Migrations.CreateSourceTable do
  use Ecto.Migration

  def change do
    create table(:source) do
      add(:name, :string)
      add(:link, :text)
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
