defmodule Dbservice.Repo.Migrations.AddG12GraduatingYearToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :g12_graduating_year, :integer
    end
  end
end
