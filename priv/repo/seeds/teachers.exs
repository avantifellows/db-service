alias Dbservice.Repo
alias Dbservice.Users.Teacher
alias Dbservice.Subjects.Subject
alias Dbservice.Profiles.{UserProfile, TeacherProfile}

IO.puts("  → Seeding teachers...")

# Get existing subjects from database
subjects = Repo.all(Subject)

if Enum.empty?(subjects) do
  IO.puts("    ⚠️  No subjects found. Skipping teacher seeding.")
else
  # Designations for teachers
  designations = [
    "Assistant Professor",
    "Associate Professor",
    "Professor",
    "Lecturer",
    "Senior Lecturer",
    "Principal",
    "Vice Principal",
    "Head of Department",
    "Teacher",
    "Senior Teacher"
  ]

  # Create 8 teachers
  teachers_created = for i <- 1..8 do
    # Create user for this teacher using the centralized function
    email = "teacher_#{String.downcase(Faker.Person.first_name())}_#{i}@example.com"
    user = UserSeeder.create_user_with_role("teacher", email)
    teacher_id = "#{String.pad_leading(to_string(user.id), 10, "0")}"

    unless Repo.get_by(Teacher, user_id: user.id) do
      teacher_attrs = %{
        user_id: user.id,
        subject_id: Enum.random(subjects).id,
        teacher_id: teacher_id,
        designation: Enum.random(designations),
        is_af_teacher: Enum.random([true, false])
      }

      teacher = %Teacher{}
      |> Teacher.changeset(teacher_attrs)
      |> Repo.insert!()

      # Get the user_profile for this teacher
      user_profile = Repo.get_by!(UserProfile, user_id: user.id)

      # Create TeacherProfile for the new teacher
      schools = ["Avanti Learning Centre", "Government School", "Private School", "International School"]
      program_managers = ["John Doe", "Jane Smith", "Alex Johnson", "Sarah Wilson", "Mike Davis"]

      %TeacherProfile{}
      |> TeacherProfile.changeset(%{
        teacher_fk: teacher.id,
        user_profile_id: user_profile.id,
        teacher_id: teacher_id,
        school: Enum.random(schools),
        program_manager: Enum.random(program_managers),
        avg_rating: "#{Enum.random(3..5)}.#{Enum.random(10..99)}"
      })
      |> Repo.insert!()

      teacher
    else
      nil
    end
  end

  actual_teachers_created = Enum.count(teachers_created, &(&1 != nil))
  IO.puts("    ✅ Teachers seeded (8 users created, #{actual_teachers_created} new teachers)")
end
