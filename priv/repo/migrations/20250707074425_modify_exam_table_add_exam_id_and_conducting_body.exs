defmodule Dbservice.Repo.Migrations.ModifyExamTableAddExamIdAndConductingBody do
  use Ecto.Migration

  def change do
    # Add the new columns
    alter table(:exam) do
      add :exam_id, :string
      add :conductingbody, :string
    end

    # Make exam_id required
    alter table(:exam) do
      modify :exam_id, :string, null: false
    end

    # Create a unique index on exam_id
    create unique_index(:exam, [:exam_id])
  end
end
