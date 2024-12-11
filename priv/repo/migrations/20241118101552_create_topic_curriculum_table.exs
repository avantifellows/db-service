defmodule Dbservice.Repo.Migrations.CreateTopicCurriculumTable do
  use Ecto.Migration

  def up do
    create table(:topic_curriculum) do
      add :topic_id, references(:topic)
      add :curriculum_id, references(:curriculum)
      add :priority, :string

      timestamps()
    end
  end

  def down do
    drop table(:topic_curriculum)
  end
end
