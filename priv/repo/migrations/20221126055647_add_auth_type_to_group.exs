defmodule Dbservice.Repo.Migrations.AddAuthTypeToGroup do
  use Ecto.Migration

  def change do
    alter table("group") do
      add :auth_type, {:array, :string}
    end
  end
end
