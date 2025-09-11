import Ecto.Query
alias Dbservice.Repo

IO.puts("→ Seeding topic curriculum...")

# Fetch all available topics and curriculums from database
all_topics = Repo.all(from t in "topic", select: %{id: t.id})
all_curriculums = Repo.all(from c in "curriculum", select: %{id: c.id})

IO.puts("→ Found #{length(all_topics)} topics and #{length(all_curriculums)} curriculums")

# Skip if no topics or curriculums exist
if length(all_topics) == 0 or length(all_curriculums) == 0 do
  IO.puts("  ⚠️  No topics or curriculums found. Skipping topic_curriculum seeding.")
else
  # Get existing topic-curriculum combinations to avoid duplicates
  existing_combinations =
    from(tc in "topic_curriculum", select: {tc.topic_id, tc.curriculum_id})
    |> Repo.all()
    |> MapSet.new()

  IO.puts("→ Found #{MapSet.size(existing_combinations)} existing topic-curriculum associations")

  # Priority levels and text
  priority_options = [
    {1, "High"},
    {2, "Medium"},
    {3, "Low"},
    {4, "Optional"}
  ]

  # Generate random topic-curriculum combinations that don't exist
  target_count = min(150, length(all_topics) * length(all_curriculums))

  combinations_to_create =
    for _i <- 1..target_count, reduce: [] do
      acc ->
        if length(acc) >= target_count do
          acc
        else
          topic = Enum.random(all_topics)
          curriculum = Enum.random(all_curriculums)
          {priority, priority_text} = Enum.random(priority_options)

          combination = {topic.id, curriculum.id}

          if combination in existing_combinations or
             Enum.any?(acc, fn %{topic_id: t_id, curriculum_id: c_id} -> t_id == topic.id and c_id == curriculum.id end) do
            acc
          else
            [%{
              topic_id: topic.id,
              curriculum_id: curriculum.id,
              priority: priority,
              priority_text: priority_text,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            } | acc]
          end
        end
    end

  IO.puts("→ Will create #{length(combinations_to_create)} new topic curriculum records")

  # Insert topic curriculum records in batches
  if length(combinations_to_create) > 0 do
    try do
      {count, _} = Repo.insert_all("topic_curriculum", combinations_to_create)
      IO.puts("  ✅ Created #{count} topic curriculum records")
    rescue
      e ->
        IO.puts("  ⚠️  Error inserting topic curriculums: #{inspect(e)}")

        # Try individual inserts
        topic_curriculums_created =
          for attrs <- combinations_to_create do
            try do
              Repo.insert_all("topic_curriculum", [attrs])
              1
            rescue
              _error -> 0
            end
          end
          |> Enum.sum()

        IO.puts("  ✅ Created #{topic_curriculums_created} topic curriculum records (individual inserts)")
    end
  else
    IO.puts("→ No new topic curriculum combinations to create")
  end
end
