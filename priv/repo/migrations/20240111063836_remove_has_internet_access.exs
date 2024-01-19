defmodule Dbservice.Repo.Migrations.RemoveHasInternetAccess do
  use Ecto.Migration

  def change do
    alter table(:session) do
      remove :has_internet_access
    end
  end
end
