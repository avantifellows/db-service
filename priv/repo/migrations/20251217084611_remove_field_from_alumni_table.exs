defmodule Dbservice.Repo.Migrations.RemoveFieldFromAlumniTable do
  use Ecto.Migration

  def change do
    alter table(:alumni) do
      remove :seeking_employment
    end
  end
end
