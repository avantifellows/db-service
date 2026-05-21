defmodule Dbservice.Repo.Migrations.RenameCmsPermissionAndAddColumns do
  use Ecto.Migration

  def up do
    # Rename cms_permission -> cms_user_permission (consistent with planned
    # lms_user_permission naming on the LMS side).
    rename table(:cms_permission), to: table(:cms_user_permission)

    execute "ALTER SEQUENCE cms_permission_id_seq RENAME TO cms_user_permission_id_seq"
    execute "ALTER INDEX cms_permission_email_index RENAME TO cms_user_permission_email_index"

    alter table(:cms_user_permission) do
      add :full_name, :string
      add :is_active, :boolean, null: false, default: true
      add :last_login_at, :utc_datetime
    end

    execute """
    ALTER TABLE cms_user_permission
    ADD CONSTRAINT cms_user_permission_role_check
    CHECK (role IN ('viewer', 'editor', 'admin'))
    """

    execute """
    CREATE INDEX cms_user_permission_email_lower_index
    ON cms_user_permission (LOWER(email))
    """

    # Seed first admin so someone can log in after the OAuth flow lands.
    execute """
    INSERT INTO cms_user_permission (email, role, full_name, is_active, inserted_at, updated_at)
    VALUES ('pritam@avantifellows.org', 'admin', 'Pritam Sukumar', true, NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM cms_user_permission WHERE email = 'pritam@avantifellows.org'"

    execute "DROP INDEX IF EXISTS cms_user_permission_email_lower_index"

    execute "ALTER TABLE cms_user_permission DROP CONSTRAINT IF EXISTS cms_user_permission_role_check"

    alter table(:cms_user_permission) do
      remove :last_login_at
      remove :is_active
      remove :full_name
    end

    execute "ALTER INDEX cms_user_permission_email_index RENAME TO cms_permission_email_index"
    execute "ALTER SEQUENCE cms_user_permission_id_seq RENAME TO cms_permission_id_seq"

    rename table(:cms_user_permission), to: table(:cms_permission)
  end
end
