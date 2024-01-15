defmodule Dbservice.Repo.Migrations.AddCurriculumIdToChapter do
  use Ecto.Migration

  def change do
    alter table(:chapter) do
      add(:curriculum_id, references(:curriculum, on_delete: :nothing))
    end
  end
end
