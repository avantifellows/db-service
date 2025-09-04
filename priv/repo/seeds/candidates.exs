alias Dbservice.Repo
alias Dbservice.Users.Candidate
alias Dbservice.Subjects.Subject

IO.puts("→ Seeding candidates...")

# Get existing subjects from database
subjects = Repo.all(Subject)

if Enum.empty?(subjects) do
  IO.puts("    ⚠️  No subjects found. Skipping candidate seeding.")
else
  # Degrees and branches for candidates
  degrees = ["B.Tech", "B.Sc", "M.Tech", "M.Sc", "B.A", "M.A", "B.Com", "M.Com", "B.Ed", "M.Ed", "PhD"]
  branches = [
    "Computer Science", "Information Technology", "Electronics", "Mechanical",
    "Civil", "Electrical", "Mathematics", "Physics", "Chemistry", "Biology",
    "English", "Hindi", "History", "Geography", "Economics", "Commerce",
    "Education", "Psychology", "Sociology"
  ]

  colleges = [
    "Indian Institute of Technology", "Indian Institute of Science",
    "Delhi University", "Jawaharlal Nehru University", "Banaras Hindu University",
    "Jamia Millia Islamia", "Aligarh Muslim University", "University of Mumbai",
    "University of Calcutta", "Madras University", "University of Pune",
    "Bangalore University", "Hyderabad University", "Cochin University"
  ]

  # Create 6 candidates
  candidates_created = for i <- 1..6 do
    # Create user for this candidate using the centralized function
    email = "candidate_#{String.downcase(Faker.Person.first_name())}_#{i}@example.com"
    user = UserSeeder.create_user_with_role("candidate", email)
    candidate_id = "#{String.pad_leading(to_string(user.id), 10, "0")}"

    unless Repo.get_by(Candidate, user_id: user.id) do
      candidate_attrs = %{
        user_id: user.id,
        subject_id: Enum.random(subjects).id,
        candidate_id: candidate_id,
        degree: Enum.random(degrees),
        college_name: Enum.random(colleges),
        branch_name: Enum.random(branches),
        latest_cgpa: Enum.random(6..9)
      }

      %Candidate{}
      |> Candidate.changeset(candidate_attrs)
      |> Repo.insert!()
    else
      nil
    end
  end

  actual_candidates_created = Enum.count(candidates_created, &(&1 != nil))
  IO.puts("    ✅ Candidates seeded (6 users created, #{actual_candidates_created} new candidates)")
end
