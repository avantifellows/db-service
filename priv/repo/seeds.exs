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
  "priv/repo/seeds/users.exs",
  "priv/repo/seeds/grades.exs",
  "priv/repo/seeds/subjects.exs",
  "priv/repo/seeds/products.exs",
  "priv/repo/seeds/auth_groups.exs",
  "priv/repo/seeds/schools.exs",
  "priv/repo/seeds/status.exs",
  "priv/repo/seeds/languages.exs",
  "priv/repo/seeds/purposes.exs",
  "priv/repo/seeds/tags.exs",
  "priv/repo/seeds/skills.exs",
  "priv/repo/seeds/colleges.exs",
  "priv/repo/seeds/curriculums.exs",

  # Programs (depend on products)
  "priv/repo/seeds/programs.exs",

  # Batches (depend on programs and auth_groups)
  "priv/repo/seeds/batches.exs",

  # Dependent models (depend on the above)
  # depends on users + grades
  "priv/repo/seeds/students.exs",
  # depends on users + subjects
  "priv/repo/seeds/teachers.exs",
  # depends on users + subjects
  "priv/repo/seeds/candidates.exs",

  # Chapters (depend on grades and subjects)
  "priv/repo/seeds/chapters.exs",

  # Topics (depend on chapters)
  "priv/repo/seeds/topics.exs",

  # Chapter curriculums (depend on chapters and curriculums)
  "priv/repo/seeds/chapter_curriculums.exs",

  # Groups (depend on products, auth_groups, schools, batches, status)
  "priv/repo/seeds/groups.exs",

  # School batches (depend on schools and batches)
  "priv/repo/seeds/school_batches.exs",

  # Session-related models
  # Form schemas (no dependencies)
  "priv/repo/seeds/form_schemas.exs",
  # Sessions (depend on form schemas and users)
  "priv/repo/seeds/sessions.exs",
  # Group sessions (depend on groups and sessions)
  "priv/repo/seeds/group_sessions.exs",
  # Session occurrences (depend on sessions)
  "priv/repo/seeds/session_occurrences.exs",
  # User sessions (depend on session occurrences and users)
  "priv/repo/seeds/user_sessions.exs",

  # Exam-related models
  # Exams (no dependencies)
  "priv/repo/seeds/exams.exs",
  # Student exam records (depend on students and exams)
  "priv/repo/seeds/student_exam_records.exs",
  # Test rules (depend on exams)
  "priv/repo/seeds/test_rules.exs",

  # Problem languages (depend on resources and languages)
  "priv/repo/seeds/problem_languages.exs",

  # Concepts (depend on topics)
  "priv/repo/seeds/concepts.exs",

  # Resource topics (depend on resources and topics)
  "priv/repo/seeds/resource_topics.exs",

  # Resource concepts (depend on resources and concepts)
  "priv/repo/seeds/resource_concepts.exs",

  # Enrollment system (depends on students, schools, batches, auth_groups, grades)
  "priv/repo/seeds/enrollments.exs"
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
