defmodule Dbservice.Repo.Migrations.AddProgramIdsToUserPermission do
  use Ecto.Migration

  def change do
    alter table(:user_permission) do
      add :program_ids, {:array, :integer}, default: []
    end
  end
end
