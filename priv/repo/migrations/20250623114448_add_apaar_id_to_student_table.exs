defmodule Dbservice.Repo.Migrations.AddApaarIdToStudentTable do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :apaar_id, :string
    end
  end
end
