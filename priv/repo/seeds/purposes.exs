alias Dbservice.Repo

IO.puts("  → Seeding purposes...")

# Purpose data from dump
purposes_data = [
  %{name: "conceptVideo", description: nil},
  %{name: "conceptTestVideo", description: nil},
  %{name: "summaryVideo", description: nil},
  %{name: "introVideo", description: nil},
  %{name: "recallTestVideo", description: nil},
  %{name: "problemSolvingVideo", description: nil},
  %{name: "classRecording", description: nil}
]

purposes_created =
  for purpose_data <- purposes_data do
    # Check if purpose already exists by name
    existing_purpose = Repo.get_by(Dbservice.Purposes.Purpose, name: purpose_data.name)

    if existing_purpose do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Purposes.Purpose{} |> Dbservice.Purposes.Purpose.changeset(purpose_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{purposes_created} purposes")
