defmodule Dbservice.Repo.Migrations.AddFieldsToAlumniTable do
  use Ecto.Migration

  def change do
    alter table(:alumni) do
      add :scholarship_availed, :string
      add :skilling_programs, :string
    end
  end
end
