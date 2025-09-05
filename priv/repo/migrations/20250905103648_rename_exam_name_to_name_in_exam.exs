defmodule Dbservice.Repo.Migrations.RenameExamNameToNameInExam do
  use Ecto.Migration

  def change do
    rename table(:exam), :exam_name, to: :name
  end
end
