defmodule DbService.Repo.Migrations.AddFullNameToUserPermission do
  use Ecto.Migration

  def change do
    alter table(:user_permission) do
      add :full_name, :string
    end
  end
end
