defmodule Dbservice.Repo.Migrations.AlterExamTable do
  use Ecto.Migration

  def change do
    alter table(:exam) do
      add :counselling_body, :string
      add :type, :string

      remove :registration_deadline
      remove :date
      remove :exam_id
      remove :cutoff_id
      remove :conducting_body
      remove :cutoff
    end
  end
end
