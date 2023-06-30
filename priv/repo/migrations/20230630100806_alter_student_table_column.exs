defmodule Dbservice.Repo.Migrations.AlterStudentTable do
  use Ecto.Migration

  def change do
    alter table(:session) do
      modify(:has_internet_access, :string)
    end
  end
end
