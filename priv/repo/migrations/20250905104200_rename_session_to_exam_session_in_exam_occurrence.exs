defmodule Dbservice.Repo.Migrations.RenameSessionToExamSessionInExamOccurrence do
  use Ecto.Migration

  def change do
    rename table(:exam_occurrence), :session, to: :exam_session
  end
end
