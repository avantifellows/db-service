# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Dbservice.Repo.insert!(%Dbservice.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

IO.puts("🌱 Running seeds...")

# Define seed files in dependency order
# Models with no dependencies first, then dependent models
seed_files = [
  # Independent models (no dependencies)
  "priv/repo/seeds/users/users.exs",
  "priv/repo/seeds/grades/grades.exs",
  "priv/repo/seeds/subjects/subjects.exs",

  # Dependent models (depend on the above)
  # depends on users + grades
  "priv/repo/seeds/users/students.exs",
  # depends on users + subjects
  "priv/repo/seeds/users/teachers.exs",
  # depends on users + subjects
  "priv/repo/seeds/users/candidates.exs"
]

# Run seed files in order
seed_files
|> Enum.each(fn file ->
  if File.exists?(file) do
    IO.puts("→ Running #{Path.relative_to_cwd(file)}")
    Code.require_file(file)
  else
    IO.puts("⚠️  Skipping missing file: #{Path.relative_to_cwd(file)}")
  end
end)

IO.puts("Seeding completed ✅")
