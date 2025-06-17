defmodule Dbservice.Repo.Migrations.AddBoardStreamToStudentTable do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :board_stream, :string
    end
  end
end
