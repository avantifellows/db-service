alias Dbservice.Repo

IO.puts("  → Seeding tags...")

# Tag data
tags_data = [
  %{name: "Archive", description: nil},
  %{name: "Final", description: nil},
  %{name: "Review", description: nil},
  %{name: "Draft", description: nil}
]

tags_created =
  for tag_data <- tags_data do
    # Check if tag already exists by name
    existing_tag = Repo.get_by(Dbservice.Tags.Tag, name: tag_data.name)

    if existing_tag do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Tags.Tag{} |> Dbservice.Tags.Tag.changeset(tag_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{tags_created} tags")
