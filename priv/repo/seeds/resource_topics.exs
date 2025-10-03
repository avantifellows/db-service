alias Dbservice.Repo
alias Dbservice.Resources.ResourceTopic
alias Dbservice.Resources.Resource
alias Dbservice.Topics.Topic
import Ecto.Query

IO.puts("→ Seeding resource topics...")

# Fetch all available resources and topics from database
all_resources = Repo.all(Resource)
all_topics = Repo.all(Topic)

IO.puts("→ Found #{length(all_resources)} resources and #{length(all_topics)} topics")

# Skip if no resources or topics exist
if length(all_resources) == 0 or length(all_topics) == 0 do
  IO.puts("  ⚠️  No resources or topics found. Skipping resource_topic seeding.")
else
  # Get existing resource-topic combinations to avoid duplicates
  existing_combinations =
    from(rt in ResourceTopic, select: {rt.resource_id, rt.topic_id})
    |> Repo.all()
    |> MapSet.new()

  # Generate random resource-topic combinations that don't exist
  target_count = min(100, length(all_resources) * length(all_topics))

  combinations_to_create =
    for _i <- 1..target_count, reduce: [] do
      acc ->
        if length(acc) >= target_count do
          acc
        else
          resource = Enum.random(all_resources)
          topic = Enum.random(all_topics)
          combination = {resource.id, topic.id}

          if combination in existing_combinations or
             Enum.any?(acc, fn {r_id, t_id} -> r_id == resource.id and t_id == topic.id end) do
            acc
          else
            [{resource.id, topic.id} | acc]
          end
        end
    end

  IO.puts("→ Will create #{length(combinations_to_create)} new resource topic records")

  # Create resource topic records
  resource_topics_created =
    for {resource_id, topic_id} <- combinations_to_create do
      attrs = %{
        resource_id: resource_id,
        topic_id: topic_id
      }

      case %ResourceTopic{} |> ResourceTopic.changeset(attrs) |> Repo.insert() do
        {:ok, _} -> 1
        {:error, changeset} ->
          IO.puts("  ⚠️  Failed to create resource topic: #{inspect(changeset.errors)}")
          0
      end
    end
    |> Enum.sum()

  IO.puts("  ✅ Created #{resource_topics_created} resource topic records")
end
