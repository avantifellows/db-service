defmodule Dbservice.Repo.Migrations.AddFieldsToExam do
  use Ecto.Migration

  def change do
    alter table(:exam) do
      add :exam_id, :string
      add :cutoff_id, :string
      add :conducting_body, :string
    end
  end
end
