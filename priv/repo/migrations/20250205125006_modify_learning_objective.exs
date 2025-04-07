defmodule Dbservice.Repo.Migrations.ModifyLearningObjective do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE learning_objective ALTER COLUMN title TYPE jsonb USING jsonb_build_object('en', title)"
  end

  def down do
    execute "ALTER TABLE learning_objective ALTER COLUMN title TYPE varchar USING title->>'en'"
  end
end
