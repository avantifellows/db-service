defmodule Dbservice.Repo.Migrations.CreateConceptTable do
  use Ecto.Migration

  def change do
    create table(:concept) do
      add(:name, :string)
      add(:topic_id, references(:topic, on_delete: :nothing))
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
