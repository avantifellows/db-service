defmodule Dbservice.Repo.Migrations.AlterUserPermission do
  use Ecto.Migration

  def up do
    # Modify school_codes column type from string array to text array
    execute "ALTER TABLE user_permission ALTER COLUMN school_codes TYPE TEXT[]"

    # Modify regions column type from string array to text array
    execute "ALTER TABLE user_permission ALTER COLUMN regions TYPE TEXT[]"

    # Add the role column with default value only if it doesn't exist
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_permission' AND column_name = 'role'
      ) THEN
        ALTER TABLE user_permission ADD COLUMN role VARCHAR(50) DEFAULT 'teacher';
      END IF;
    END $$;
    """

    # Add index on role if it doesn't exist
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'user_permission' AND indexname = 'user_permission_role_index'
      ) THEN
        CREATE INDEX user_permission_role_index ON user_permission(role);
      END IF;
    END $$;
    """

    # Update existing records to set role based on level
    execute """
    UPDATE user_permission
    SET role = CASE
      WHEN level = 4 THEN 'admin'
      WHEN level = 3 THEN 'program_manager'
      ELSE 'teacher'
    END
    WHERE role = 'teacher' OR role IS NULL
    """
  end

  def down do
    # Remove the role index
    drop_if_exists index(:user_permission, [:role])

    # Remove the role column
    alter table(:user_permission) do
      remove_if_exists :role, :string
    end

    # Revert school_codes column type back to string array
    execute "ALTER TABLE user_permission ALTER COLUMN school_codes TYPE VARCHAR(255)[]"

    # Revert regions column type back to string array
    execute "ALTER TABLE user_permission ALTER COLUMN regions TYPE VARCHAR(255)[]"
  end
end
