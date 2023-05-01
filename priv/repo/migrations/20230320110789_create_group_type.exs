defmodule Dbservice.Repo.Migrations.CreateGroupType do
  use Ecto.Migration

  def change do
    create table(:group_type) do
      add :type, :string
      add :child_id, :integer

      timestamps()
    end
  end
end
