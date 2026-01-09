defmodule Dbservice.Repo.Migrations.AddCmsStatusToChapterAndTopic do
  use Ecto.Migration

  def change do
    alter table(:chapter) do
      add :cms_status_id, references(:cms_status, on_delete: :restrict)
    end

    create index(:chapter, [:cms_status_id])

    alter table(:topic) do
      add :cms_status_id, references(:cms_status, on_delete: :restrict)
    end

    create index(:topic, [:cms_status_id])
  end
end
