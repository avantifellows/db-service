defmodule Dbservice.Repo.Migrations.CreateUserPermissionTable do
  use Ecto.Migration

  def change do
    create table(:user_permission) do
      add :email, :string, null: false
      add :level, :integer, null: false
      add :school_codes, {:array, :string}
      add :regions, {:array, :string}
      add :read_only, :boolean, default: false

      timestamps()
    end

    # Add unique index on email
    create unique_index(:user_permission, [:email])

    # Add index for case-insensitive lookup
    create index(:user_permission, ["lower(email)"])

    # Level constraint: 1,2,3,4 only
    create constraint(:user_permission, :level_constraint, check: "level IN (1, 2, 3, 4)")
  end
end
