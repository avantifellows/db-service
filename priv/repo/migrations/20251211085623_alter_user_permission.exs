defmodule Dbservice.Repo.Migrations.AlterUserPermission do
  use Ecto.Migration

  def up do
    # Modify school_codes column type from string array to text array
    execute "ALTER TABLE user_permission ALTER COLUMN school_codes TYPE TEXT[]"

    # Modify regions column type from string array to text array
    execute "ALTER TABLE user_permission ALTER COLUMN regions TYPE TEXT[]"

    # Add the role column with default value
    alter table(:user_permission) do
      add :role, :string, default: "teacher", size: 50
    end

    # Add index on role
    create index(:user_permission, [:role])

    # Update existing records to set role based on level
    execute """
    UPDATE user_permission
    SET role = CASE
      WHEN level = 4 THEN 'admin'
      WHEN level = 3 THEN 'program_manager'
      ELSE 'teacher'
    END
    """
  end

  def down do
    # Remove the role index
    drop index(:user_permission, [:role])

    # Remove the role column
    alter table(:user_permission) do
      remove :role
    end

    # Revert school_codes column type back to string array
    execute "ALTER TABLE user_permission ALTER COLUMN school_codes TYPE VARCHAR(255)[]"

    # Revert regions column type back to string array
    execute "ALTER TABLE user_permission ALTER COLUMN regions TYPE VARCHAR(255)[]"
  end
end
