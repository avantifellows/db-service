alias Dbservice.Repo

IO.puts("  → Seeding skills...")

# Student-related skills data
skills_data = [
  %{name: "Mathematics"},
  %{name: "Physics"},
  %{name: "Chemistry"},
  %{name: "Biology"},
  %{name: "Computer Science"},
  %{name: "Programming"},
  %{name: "Data Analysis"},
  %{name: "Problem Solving"},
  %{name: "Critical Thinking"},
  %{name: "Communication"},
  %{name: "Leadership"},
  %{name: "Time Management"},
  %{name: "Research"},
  %{name: "Writing"},
  %{name: "Presentation"},
  %{name: "Teamwork"},
  %{name: "Analytical Thinking"},
  %{name: "Creative Thinking"},
  %{name: "Project Management"},
  %{name: "Technical Writing"},
  %{name: "Laboratory Skills"},
  %{name: "Statistical Analysis"},
  %{name: "Software Development"},
  %{name: "Database Management"},
  %{name: "Web Development"},
  %{name: "Mobile App Development"},
  %{name: "Machine Learning"},
  %{name: "Artificial Intelligence"},
  %{name: "Data Visualization"},
  %{name: "Public Speaking"}
]

skills_created =
  for skill_data <- skills_data do
    # Check if skill already exists by name
    existing_skill = Repo.get_by(Dbservice.Skills.Skill, name: skill_data.name)

    if existing_skill do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Skills.Skill{} |> Dbservice.Skills.Skill.changeset(skill_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{skills_created} skills")
