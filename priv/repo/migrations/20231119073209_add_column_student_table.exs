defmodule Dbservice.Repo.Migrations.AddColumnStudentTable do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add(:planned_competitive_exams, {:array, :integer})
    end
  end
end
