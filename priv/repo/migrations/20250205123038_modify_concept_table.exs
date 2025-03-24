defmodule Dbservice.Repo.Migrations.ModifyConceptTable do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE concept ALTER COLUMN name TYPE jsonb USING jsonb_build_object('en', name)"
  end

  def down do
    execute "ALTER TABLE concept ALTER COLUMN name TYPE varchar USING name->>'en'"
  end
end
