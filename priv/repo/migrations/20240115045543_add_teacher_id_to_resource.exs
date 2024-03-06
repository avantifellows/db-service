defmodule Dbservice.Repo.Migrations.AddTeacherIdToResource do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add(:teacher_id, references(:teacher, on_delete: :nothing))
    end
  end
end
