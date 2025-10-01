import Ecto.Query
alias Dbservice.Repo

IO.puts("→ Seeding resource chapter...")

# Fetch all available resources and chapters from database
all_resources = Repo.all(from r in "resource", select: %{id: r.id})
all_chapters = Repo.all(from c in "chapter", select: %{id: c.id})

IO.puts("→ Found #{length(all_resources)} resources and #{length(all_chapters)} chapters")

# Skip if no resources or chapters exist
if length(all_resources) == 0 or length(all_chapters) == 0 do
  IO.puts("  ⚠️  No resources or chapters found. Skipping resource_chapter seeding.")
else
  # Get existing resource-chapter combinations to avoid duplicates
  existing_combinations =
    from(rc in "resource_chapter", select: {rc.resource_id, rc.chapter_id})
    |> Repo.all()
    |> MapSet.new()

  IO.puts("→ Found #{MapSet.size(existing_combinations)} existing resource-chapter associations")

  # Generate random resource-chapter combinations that don't exist
  target_count = min(250, length(all_resources) * length(all_chapters))

  combinations_to_create =
    for _i <- 1..target_count, reduce: [] do
      acc ->
        if length(acc) >= target_count do
          acc
        else
          resource = Enum.random(all_resources)
          chapter = Enum.random(all_chapters)
          combination = {resource.id, chapter.id}

          if combination in existing_combinations or
             Enum.any?(acc, fn %{resource_id: r_id, chapter_id: c_id} -> r_id == resource.id and c_id == chapter.id end) do
            acc
          else
            [%{
              resource_id: resource.id,
              chapter_id: chapter.id,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            } | acc]
          end
        end
    end

  IO.puts("→ Will create #{length(combinations_to_create)} new resource chapter records")

  # Insert resource chapter records in batches
  if length(combinations_to_create) > 0 do
    try do
      {count, _} = Repo.insert_all("resource_chapter", combinations_to_create)
      IO.puts("  ✅ Created #{count} resource chapter records")
    rescue
      e ->
        IO.puts("  ⚠️  Error inserting resource chapters: #{inspect(e)}")

        # Try individual inserts
        resource_chapters_created =
          for attrs <- combinations_to_create do
            try do
              Repo.insert_all("resource_chapter", [attrs])
              1
            rescue
              _error -> 0
            end
          end
          |> Enum.sum()

        IO.puts("  ✅ Created #{resource_chapters_created} resource chapter records (individual inserts)")
    end
  else
    IO.puts("→ No new resource chapter combinations to create")
  end
end
