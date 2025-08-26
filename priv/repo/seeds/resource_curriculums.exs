import Ecto.Query
alias Dbservice.Repo

IO.puts("  → Seeding resource curriculum...")

# Fetch all available entities from database
all_resources = Repo.all(from r in "resource", select: %{id: r.id})
all_curriculums = Repo.all(from c in "curriculum", select: %{id: c.id})
all_grades = Repo.all(from g in "grade", select: %{id: g.id})
all_subjects = Repo.all(from s in "subject", select: %{id: s.id})

IO.puts("  → Found #{length(all_resources)} resources, #{length(all_curriculums)} curriculums, #{length(all_grades)} grades, #{length(all_subjects)} subjects")

# Skip if any required entities don't exist
if length(all_resources) == 0 or length(all_curriculums) == 0 or length(all_grades) == 0 or length(all_subjects) == 0 do
  IO.puts("  ⚠️  Missing required entities (resources, curriculums, grades, or subjects). Skipping resource_curriculum seeding.")
else
  # Get existing resource-curriculum combinations to avoid duplicates
  existing_combinations =
    from(rc in "resource_curriculum", select: {rc.resource_id, rc.curriculum_id, rc.grade_id, rc.subject_id})
    |> Repo.all()
    |> MapSet.new()

  IO.puts("  → Found #{MapSet.size(existing_combinations)} existing resource-curriculum associations")

  # Difficulty levels
  difficulty_levels = ["easy", "medium", "hard", nil]

  # Generate random resource-curriculum combinations that don't exist
  target_count = min(200, length(all_resources) * length(all_curriculums))

  combinations_to_create =
    for _i <- 1..target_count, reduce: [] do
      acc ->
        if length(acc) >= target_count do
          acc
        else
          resource = Enum.random(all_resources)
          curriculum = Enum.random(all_curriculums)
          grade = Enum.random(all_grades)
          subject = Enum.random(all_subjects)
          difficulty = Enum.random(difficulty_levels)

          combination = {resource.id, curriculum.id, grade.id, subject.id}

          if combination in existing_combinations or
             Enum.any?(acc, fn %{resource_id: r_id, curriculum_id: c_id, grade_id: g_id, subject_id: s_id} ->
               r_id == resource.id and c_id == curriculum.id and g_id == grade.id and s_id == subject.id
             end) do
            acc
          else
            [%{
              resource_id: resource.id,
              curriculum_id: curriculum.id,
              grade_id: grade.id,
              subject_id: subject.id,
              difficulty_level: difficulty,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            } | acc]
          end
        end
    end

  IO.puts("  → Will create #{length(combinations_to_create)} new resource curriculum records")

  # Insert resource curriculum records in batches
  if length(combinations_to_create) > 0 do
    try do
      {count, _} = Repo.insert_all("resource_curriculum", combinations_to_create)
      IO.puts("  ✅ Created #{count} resource curriculum records")
    rescue
      e ->
        IO.puts("  ⚠️  Error inserting resource curriculums: #{inspect(e)}")

        # Try individual inserts
        resource_curriculums_created =
          for attrs <- combinations_to_create do
            try do
              Repo.insert_all("resource_curriculum", [attrs])
              1
            rescue
              _error -> 0
            end
          end
          |> Enum.sum()

        IO.puts("  ✅ Created #{resource_curriculums_created} resource curriculum records (individual inserts)")
    end
  else
    IO.puts("  → No new resource curriculum combinations to create")
  end
end
