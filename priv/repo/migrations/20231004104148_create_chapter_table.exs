defmodule Dbservice.Repo.Migrations.CreateChapterTable do
  use Ecto.Migration

  def change do
    create table(:chapter) do
      add(:name, :string)
      add(:code, :string)
      add(:grade_id, references(:grade, on_delete: :nothing))
      add(:subject_id, references(:subject, on_delete: :nothing))
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
