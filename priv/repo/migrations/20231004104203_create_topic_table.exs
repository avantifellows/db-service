defmodule Dbservice.Repo.Migrations.CreateTopicTable do
  use Ecto.Migration

  def change do
    create table(:topic) do
      add(:name, :string)
      add(:code, :string)
      add(:chapter_id, references(:chapter, on_delete: :nothing))
      add(:grade_id, references(:grade, on_delete: :nothing))
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
