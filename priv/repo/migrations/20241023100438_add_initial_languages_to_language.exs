defmodule Dbservice.Repo.Migrations.AddInitialLanguagesToLanguage do
  use Ecto.Migration

  def up do
    execute "TRUNCATE TABLE language RESTART IDENTITY"

    execute "INSERT INTO language (name, code, inserted_at, updated_at) VALUES ('English', 'en', NOW(), NOW())"

    execute "INSERT INTO language (name, code, inserted_at, updated_at) VALUES ('Hindi', 'hi', NOW(), NOW())"

    execute "INSERT INTO language (name, code, inserted_at, updated_at) VALUES ('Tamil', 'ta', NOW(), NOW())"

    execute "INSERT INTO language (name, code, inserted_at, updated_at) VALUES ('Gujarati', 'gu', NOW(), NOW())"
  end

  def down do
    execute "DELETE FROM language WHERE name IN ('English', 'Hindi', 'Tamil', 'Gujarati')"
  end
end
