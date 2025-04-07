defmodule Dbservice.Repo.Migrations.CreateResourceConcept do
  use Ecto.Migration

  def change do
    create table(:resource_concept) do
      add :resource_id, references(:resource, on_delete: :nothing)
      add :concept_id, references(:concept, on_delete: :nothing)

      timestamps()
    end
  end
end
