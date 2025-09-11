alias Dbservice.Repo

# Load college data from shared data file
Code.require_file("data/college_data.exs", __DIR__)
alias SeedData.CollegeData

IO.puts("→ Seeding colleges...")

# Get college data from the common source
colleges_data = CollegeData.get_colleges_data()

colleges_created =
  for college_data <- colleges_data do
    # Check if college already exists by college_id
    existing_college = Repo.get_by(Dbservice.Colleges.College, college_id: college_data.college_id)

    if existing_college do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Colleges.College{} |> Dbservice.Colleges.College.changeset(college_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{colleges_created} colleges")
