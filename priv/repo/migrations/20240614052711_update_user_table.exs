defmodule Dbservice.Repo.Migrations.UpdateUserTable do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :region, :string
    end
  end
end
