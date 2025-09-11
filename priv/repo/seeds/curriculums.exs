alias Dbservice.Repo
alias Dbservice.Curriculums.Curriculum

IO.puts("→ Seeding curriculums...")

# Curriculum data from dump
curriculums_data = [
  %{name: "JEE Mains", code: nil},
  %{name: "NEET", code: nil},
  %{name: "CA", code: nil},
  %{name: "CLAT", code: nil}
]

curriculums_created =
  for curriculum_data <- curriculums_data do
    # Check if curriculum already exists by name
    existing_curriculum = Repo.get_by(Curriculum, name: curriculum_data.name)

    if existing_curriculum do
      0  # Already exists
    else
      case Repo.insert(%Curriculum{} |> Curriculum.changeset(curriculum_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{curriculums_created} curriculums")
