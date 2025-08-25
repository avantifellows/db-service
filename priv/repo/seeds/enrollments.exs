alias Dbservice.Repo
alias Dbservice.Users.Student
alias Dbservice.Groups.Group
alias Dbservice.Groups.GroupUser
alias Dbservice.EnrollmentRecords.EnrollmentRecord
alias Dbservice.Schools.School
alias Dbservice.Batches.Batch
alias Dbservice.Groups.AuthGroup
alias Dbservice.Grades.Grade

import Ecto.Query

# Helper function to create both enrollment record and group user
create_enrollment_and_group_user = fn user_id, entity, group, group_type, academic_year, start_date ->
  # First create enrollment record (uses entity.id as group_id)
  enrollment_attrs = %{
    user_id: user_id,
    group_id: entity.id,
    group_type: group_type,
    academic_year: academic_year,
    start_date: start_date,
    is_current: true
  }

  # Then create group user record (uses groups table id as group_id)
  group_user_attrs = %{
    user_id: user_id,
    group_id: group.id
  }

  # Check if enrollment record already exists
  enrollment_exists = Repo.get_by(EnrollmentRecord, [
    user_id: user_id,
    group_id: entity.id,
    group_type: group_type,
    academic_year: academic_year
  ])

  # Check if group user already exists
  group_user_exists = Repo.get_by(GroupUser, [
    user_id: user_id,
    group_id: group.id
  ])

  # Use is_nil to avoid ArgumentError from `not` with a struct
  enrollment_created = if is_nil(enrollment_exists) do
    case Repo.insert(%EnrollmentRecord{} |> EnrollmentRecord.changeset(enrollment_attrs)) do
      {:ok, _} -> 1
      {:error, _} -> 0
    end
  else
    0
  end

  # Use is_nil to avoid ArgumentError from `not` with a struct
  group_user_created = if is_nil(group_user_exists) do
    case Repo.insert(%GroupUser{} |> GroupUser.changeset(group_user_attrs)) do
      {:ok, _} -> 1
      {:error, _} -> 0
    end
  else
    0
  end

  enrollment_created + group_user_created
end

IO.puts("  → Seeding enrollments...")

# Get all students for enrollment
students = Repo.all(Student)

# Get available entities for random assignment
schools = Repo.all(School)
batches = Repo.all(Batch)
auth_groups = Repo.all(AuthGroup)
grades = Repo.all(Grade)

# Get corresponding group records for each entity type
school_groups = Repo.all(from g in Group, where: g.type == "school")
batch_groups = Repo.all(from g in Group, where: g.type == "batch")
auth_group_groups = Repo.all(from g in Group, where: g.type == "auth_group")
grade_groups = Repo.all(from g in Group, where: g.type == "grade")

if Enum.empty?(students) do
  IO.puts("    ⚠️  No students found. Skipping enrollments seeding.")
else
  IO.puts("    → Found #{length(students)} students to enroll")
  IO.puts("    → Available: #{length(schools)} schools, #{length(batches)} batches, #{length(auth_groups)} auth groups, #{length(grades)} grades")

  # Academic years for realistic data
  academic_years = ["2024-2025", "2025-2026"]
  current_date = Date.utc_today()

  enrollments_created =
    for student <- students do
      user_id = student.user_id
      academic_year = Enum.random(academic_years)

      # Generate enrollment start date (within last 6 months to 1 year ago)
      days_ago = :rand.uniform(365) + 30  # 30 to 395 days ago
      start_date = Date.add(current_date, -days_ago)

      # 1. School Enrollment (every student should have one)
      school_result = if not Enum.empty?(schools) and not Enum.empty?(school_groups) do
        school = Enum.random(schools)
        school_group = Enum.find(school_groups, fn g -> g.child_id == school.id end)

        if school_group do
          create_enrollment_and_group_user.(user_id, school, school_group, "school", academic_year, start_date)
        else
          0
        end
      else
        0
      end

      # 2. Grade Enrollment (every student should have one based on their grade)
      grade_result = if not is_nil(student.grade_id) and not Enum.empty?(grade_groups) do
        grade_group = Enum.find(grade_groups, fn g -> g.child_id == student.grade_id end)
        grade = Enum.find(grades, fn g -> g.id == student.grade_id end)

        if grade_group and grade do
          create_enrollment_and_group_user.(user_id, grade, grade_group, "grade", academic_year, start_date)
        else
          0
        end
      else
        0
      end

      # 3. Auth Group Enrollment (100% of students)
      auth_group_result = if not Enum.empty?(auth_groups) and not Enum.empty?(auth_group_groups) do
        auth_group = Enum.random(auth_groups)
        auth_group_group = Enum.find(auth_group_groups, fn g -> g.child_id == auth_group.id end)

        if auth_group_group do

          create_enrollment_and_group_user.(user_id, auth_group, auth_group_group, "auth_group", academic_year, start_date)
        else
          0
        end
      else
        0
      end

      # 4. Batch Enrollment (100% of students)
      batch_result = if not Enum.empty?(batches) and not Enum.empty?(batch_groups) do
        batch = Enum.random(batches)
        batch_group = Enum.find(batch_groups, fn g -> g.child_id == batch.id end)

        if batch_group do
          create_enrollment_and_group_user.(user_id, batch, batch_group, "batch", academic_year, start_date)
        else
          0
        end
      else
        0
      end

      [school_result, grade_result, auth_group_result, batch_result]
    end
    |> List.flatten()
    |> Enum.sum()

  IO.puts("    ✅ Created #{enrollments_created} total enrollments (enrollment records + group users)")
end
