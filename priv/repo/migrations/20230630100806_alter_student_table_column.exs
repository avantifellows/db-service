defmodule Dbservice.Repo.Migrations.AlterStudentTable do
  use Ecto.Migration

  def change do
    alter table(:student) do
      modify(:has_internet_access, :string)
    end
  end
end
