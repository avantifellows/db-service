alias Dbservice.Repo
alias Dbservice.Users.Student
alias Dbservice.Grades.Grade

IO.puts("  → Seeding students...")

# Get existing grades from database
grades = Repo.all(Grade)

if Enum.empty?(grades) do
  IO.puts("    ⚠️  No grades found. Skipping student seeding.")
else
  # Categories for Indian students
  categories = ["Gen", "OBC", "SC", "ST", "Gen-EWS", "PWD-SC", "PWD-Gen", "PWD-OBC", "PWD-EWS", "PWD-ST"]
  streams = ["engineering", "medical", "pcmb", "pcm", "pcb", "foundation"]
  education_levels = ["Primary", "Secondary", "Higher Secondary", "Graduate", "Post Graduate"]
  professions = ["Farmer", "Teacher", "Engineer", "Doctor", "Businessman", "Government Employee", "Private Employee", "Daily Wage Worker"]
  family_types = ["Nuclear", "Joint"]
  guardian_relations = ["Uncle", "Aunt", "Grandfather", "Grandmother", "Elder Brother", "Elder Sister", "Cousin"]
  competitive_exams = [1, 2, 3, 4, 5] # Sample exam IDs

  # Create 10 students
  students_created = for i <- 1..10 do
    # Create user for this student using the centralized function
    email = "student_#{String.downcase(Faker.Person.first_name())}_#{i}@example.com"
    user = UserSeeder.create_user_with_role("student", email)
    student_id = String.pad_leading(to_string(user.id), 10, "0")

    unless Repo.get_by(Student, user_id: user.id) do
      student_attrs = %{
        user_id: user.id,
        grade_id: Enum.random(grades).id,
        student_id: student_id,
        father_name: Faker.Person.name(),
        father_phone: "#{Enum.random(7000000000..9999999999)}",
        father_education_level: Enum.random(education_levels),
        father_profession: Enum.random(professions),
        mother_name: Faker.Person.name(),
        mother_phone: "#{Enum.random(7000000000..9999999999)}",
        mother_education_level: Enum.random(education_levels),
        mother_profession: Enum.random(professions),
        guardian_name: Faker.Person.name(),
        guardian_relation: Enum.random(guardian_relations),
        guardian_phone: "#{Enum.random(7000000000..9999999999)}",
        guardian_education_level: Enum.random(education_levels),
        guardian_profession: Enum.random(professions),
        category: Enum.random(categories),
        has_category_certificate: Enum.random([true, false]),
        stream: Enum.random(streams),
        physically_handicapped: Enum.random([true, false]),
        annual_family_income: "#{Enum.random(100000..2000000)}",
        monthly_family_income: "#{Enum.random(8000..166000)}",
        time_of_device_availability: Enum.random(["Morning", "Afternoon", "Evening", "Night", "All Day"]),
        has_internet_access: Enum.random(["Yes", "No", "Sometimes"]),
        primary_smartphone_owner: Enum.random(["Father", "Mother", "Self", "Sibling"]),
        primary_smartphone_owner_profession: Enum.random(professions),
        number_of_smartphones: "#{Enum.random(1..4)}",
        family_type: Enum.random(family_types),
        number_of_four_wheelers: "#{Enum.random(0..2)}",
        number_of_two_wheelers: "#{Enum.random(0..3)}",
        has_air_conditioner: Enum.random([true, false]),
        goes_for_tuition_or_other_coaching: Enum.random(["Yes", "No"]),
        know_about_avanti: Enum.random(["Social Media", "Friends", "School", "Family", "Advertisement"]),
        percentage_in_grade_10_science: "#{Enum.random(60..95)}",
        percentage_in_grade_10_math: "#{Enum.random(60..95)}",
        percentage_in_grade_10_english: "#{Enum.random(60..95)}",
        status: "active",
        board_stream: Enum.random(["CBSE", "ICSE", "State Board"]),
        school_medium: Enum.random(["English", "Hindi", "Regional"]),
        apaar_id: "#{Enum.random(100000000000..999999999999)}"
      }

      %Student{}
      |> Student.changeset(student_attrs)
      |> Repo.insert!()
    else
      nil
    end
  end

  actual_students_created = Enum.count(students_created, &(&1 != nil))
  IO.puts("    ✅ Students seeded (10 users created, #{actual_students_created} new students)")
end
