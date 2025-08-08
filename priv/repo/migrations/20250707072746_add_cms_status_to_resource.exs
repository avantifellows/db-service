defmodule Dbservice.Repo.Migrations.AddCmsStatusToResource do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add :cms_status, :string
    end
  end
end
