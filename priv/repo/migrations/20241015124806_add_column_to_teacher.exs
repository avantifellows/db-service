defmodule Dbservice.Repo.Migrations.AddColumnToTeacher do
  use Ecto.Migration

  def change do
    alter table(:teacher) do
      add :is_af_teacher, :boolean, default: false
    end
  end
end
