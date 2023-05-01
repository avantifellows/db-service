defmodule Dbservice.Repo.Migrations.ModifyStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      remove :group_id
    end
  end
end
