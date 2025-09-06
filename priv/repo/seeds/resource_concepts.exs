alias Dbservice.Repo
alias Dbservice.Resources.ResourceConcept
alias Dbservice.Resources.Resource
alias Dbservice.Concepts.Concept
import Ecto.Query

IO.puts("  → Seeding resource concepts...")

# Fetch all available resources and concepts from database
all_resources = Repo.all(Resource)
all_concepts = Repo.all(Concept)

IO.puts("  → Found #{length(all_resources)} resources and #{length(all_concepts)} concepts")

# Skip if no resources or concepts exist
if length(all_resources) == 0 or length(all_concepts) == 0 do
  IO.puts("  ⚠️  No resources or concepts found. Skipping resource_concept seeding.")
else
  # Get existing resource-concept combinations to avoid duplicates
  existing_combinations =
    from(rc in ResourceConcept, select: {rc.resource_id, rc.concept_id})
    |> Repo.all()
    |> MapSet.new()

  # Generate random resource-concept combinations that don't exist
  target_count = min(150, length(all_resources) * length(all_concepts))

  combinations_to_create =
    for _i <- 1..target_count, reduce: [] do
      acc ->
        if length(acc) >= target_count do
          acc
        else
          resource = Enum.random(all_resources)
          concept = Enum.random(all_concepts)
          combination = {resource.id, concept.id}

          if combination in existing_combinations or
             Enum.any?(acc, fn {r_id, c_id} -> r_id == resource.id and c_id == concept.id end) do
            acc
          else
            [{resource.id, concept.id} | acc]
          end
        end
    end

  IO.puts("  → Will create #{length(combinations_to_create)} new resource concept records")

  # Create resource concept records
  resource_concepts_created =
    for {resource_id, concept_id} <- combinations_to_create do
      attrs = %{
        resource_id: resource_id,
        concept_id: concept_id
      }

      case %ResourceConcept{} |> ResourceConcept.changeset(attrs) |> Repo.insert() do
        {:ok, _} -> 1
        {:error, changeset} ->
          IO.puts("  ⚠️  Failed to create resource concept: #{inspect(changeset.errors)}")
          0
      end
    end
    |> Enum.sum()

  IO.puts("  ✅ Created #{resource_concepts_created} resource concept records")
end
