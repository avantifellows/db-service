defmodule Dbservice.Repo.Migrations.AddInitialLanguagesToLanguage do
  use Ecto.Migration

  def up do
    execute "TRUNCATE TABLE language RESTART IDENTITY"

    execute "INSERT INTO language (name, inserted_at, updated_at) VALUES ('English', NOW(), NOW())"
    execute "INSERT INTO language (name, inserted_at, updated_at) VALUES ('Hindi', NOW(), NOW())"
    execute "INSERT INTO language (name, inserted_at, updated_at) VALUES ('Tamil', NOW(), NOW())"

    execute "INSERT INTO language (name, inserted_at, updated_at) VALUES ('Gujarati', NOW(), NOW())"
  end

  def down do
    execute "DELETE FROM language WHERE name IN ('English', 'Hindi', 'Tamil', 'Gujarati')"
  end
end
