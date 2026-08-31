defmodule Dbservice.DataImport.GroupUpdateProcessorTest do
  use Dbservice.DataCase

  import Ecto.Query

  alias Dbservice.DataImport.GroupUpdateProcessor
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.GradesFixtures
  import Dbservice.AuthGroupsFixtures

  describe "process_batch_id_update/1" do
    test "successfully processes batch ID update with valid data" do
      # Create fixtures
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      old_batch = batch_fixture(%{batch_id: "OLD_BATCH"})
      new_batch = batch_fixture(%{batch_id: "NEW_BATCH"})

      # Get existing groups for the batches
      old_batch_group = Dbservice.Groups.get_group_by_child_id_and_type(old_batch.id, "batch")
      _new_batch_group = Dbservice.Groups.get_group_by_child_id_and_type(new_batch.id, "batch")

      # Create group user for the old batch
      {:ok, _group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_batch_group.id
        })

      # Create enrollment record
      {:ok, _enrollment} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: old_batch.id,
          group_type: "batch",
          is_current: true,
          start_date: ~D[2024-01-01],
          academic_year: "2024-2025"
        })

      record = %{
        "student_id" => student.student_id,
        "old_batch_id" => old_batch.batch_id,
        "batch_id" => new_batch.batch_id
      }

      result = GroupUpdateProcessor.process_batch_id_update(record)

      assert {:ok, "Batch ID update processed successfully"} = result
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "old_batch_id" => "OLD_BATCH",
        "batch_id" => "NEW_BATCH"
      }

      result = GroupUpdateProcessor.process_batch_id_update(record)

      assert {:error, "Student not found. student_id: \"NONEXISTENT_STUDENT\", apaar_id: nil"} =
               result
    end

    test "returns error when old batch is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})

      record = %{
        "student_id" => student.student_id,
        "old_batch_id" => "NONEXISTENT_BATCH",
        "batch_id" => "NEW_BATCH"
      }

      result = GroupUpdateProcessor.process_batch_id_update(record)

      assert {:error, "Batch not found with ID: NONEXISTENT_BATCH"} = result
    end

    test "returns error when new batch is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      old_batch = batch_fixture(%{batch_id: "OLD_BATCH"})

      record = %{
        "student_id" => student.student_id,
        "old_batch_id" => old_batch.batch_id,
        "batch_id" => "NONEXISTENT_BATCH"
      }

      result = GroupUpdateProcessor.process_batch_id_update(record)

      assert {:error, "Batch not found with ID: NONEXISTENT_BATCH"} = result
    end

    test "returns error when new batch group is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      old_batch = batch_fixture(%{batch_id: "OLD_BATCH"})
      new_batch = batch_fixture(%{batch_id: "NEW_BATCH"})

      record = %{
        "student_id" => student.student_id,
        "old_batch_id" => old_batch.batch_id,
        "batch_id" => new_batch.batch_id
      }

      result = GroupUpdateProcessor.process_batch_id_update(record)

      assert {:error, "Group user or enrollment record not found"} = result
    end
  end

  describe "process_school_update/1" do
    test "successfully processes school update with valid data" do
      # Create fixtures
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      school = school_fixture(%{code: "SCHOOL001"})

      # Get existing group for the school
      school_group = Dbservice.Groups.get_group_by_child_id_and_type(school.id, "school")

      # Create group user for the school
      {:ok, _group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: school_group.id
        })

      # Create enrollment record
      {:ok, _enrollment} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: school_group.id,
          group_type: "school",
          is_current: true,
          start_date: ~D[2024-01-01],
          academic_year: "2024-2025"
        })

      mapping_id = insert_active_mapping(student.id)

      record = %{
        "student_id" => student.student_id,
        "school_code" => school.code
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:ok, "School update processed successfully"} = result

      assert Repo.query!(
               "SELECT ended_at IS NULL FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
               [mapping_id]
             ).rows == [[true]]
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "school_code" => "SCHOOL001"
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:error, "Student not found. student_id: \"NONEXISTENT_STUDENT\", apaar_id: nil"} =
               result
    end

    test "returns error when school is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})

      record = %{
        "student_id" => student.student_id,
        "school_code" => "NONEXISTENT_SCHOOL"
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:error, "School not found with code: NONEXISTENT_SCHOOL"} = result
    end

    test "returns error when school group is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      school = school_fixture(%{code: "SCHOOL001"})

      record = %{
        "student_id" => student.student_id,
        "school_code" => school.code
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:error, "Group user or enrollment record not found"} = result
    end
  end

  describe "process_school_movement/1" do
    test "closes out the current school enrollment and creates a new active one for the target year" do
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      old_school = school_fixture(%{code: "OLD_SCHOOL"})
      new_school = school_fixture(%{code: "NEW_SCHOOL"})

      old_school_group = Dbservice.Groups.get_group_by_child_id_and_type(old_school.id, "school")
      new_school_group = Dbservice.Groups.get_group_by_child_id_and_type(new_school.id, "school")

      # Existing (current) school membership + enrollment for the old school
      {:ok, _group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_school_group.id
        })

      {:ok, old_enrollment} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: old_school.id,
          group_type: "school",
          is_current: true,
          start_date: ~D[2025-06-01],
          academic_year: "2025-2026"
        })

      record = %{
        "student_id" => student.student_id,
        "school_code" => new_school.code,
        "academic_year" => "2026-2027",
        "effective_date" => "2026-06-01"
      }

      assert {:ok, "School movement processed successfully"} =
               GroupUpdateProcessor.process_school_movement(record)

      # Old enrollment is preserved as history: kept, but inactive with an end date
      old = Repo.get!(EnrollmentRecord, old_enrollment.id)
      refute old.is_current
      assert old.end_date == ~D[2026-06-01]
      assert old.academic_year == "2025-2026"

      # A new active enrollment exists for the correct school and target year
      new =
        Repo.get_by(EnrollmentRecord,
          user_id: user.id,
          group_id: new_school.id,
          group_type: "school",
          academic_year: "2026-2027"
        )

      assert new
      assert new.is_current
      assert new.start_date == ~D[2026-06-01]

      # The single school membership row now points to the new school group
      school_group_ids = Repo.all(from(g in Group, where: g.type == "school", select: g.id))

      group_users =
        Repo.all(
          from(gu in GroupUser,
            where: gu.user_id == ^user.id and gu.group_id in ^school_group_ids
          )
        )

      assert [%GroupUser{group_id: gid}] = group_users
      assert gid == new_school_group.id
    end

    test "defaults effective_date to today when not provided" do
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      school = school_fixture(%{code: "NEW_SCHOOL"})

      record = %{
        "student_id" => student.student_id,
        "school_code" => school.code,
        "academic_year" => "2026-2027"
      }

      assert {:ok, "School movement processed successfully"} =
               GroupUpdateProcessor.process_school_movement(record)

      new =
        Repo.get_by(EnrollmentRecord,
          user_id: user.id,
          group_id: school.id,
          group_type: "school",
          academic_year: "2026-2027"
        )

      assert new.is_current
      assert new.start_date == Date.utc_today()
    end

    test "returns error when academic_year is missing" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      school = school_fixture(%{code: "NEW_SCHOOL"})

      record = %{"student_id" => student.student_id, "school_code" => school.code}

      assert {:error, "academic_year is required"} =
               GroupUpdateProcessor.process_school_movement(record)
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "school_code" => "NEW_SCHOOL",
        "academic_year" => "2026-2027"
      }

      assert {:error, "Student not found. student_id: \"NONEXISTENT_STUDENT\", apaar_id: nil"} =
               GroupUpdateProcessor.process_school_movement(record)
    end

    test "returns error when school is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})

      record = %{
        "student_id" => student.student_id,
        "school_code" => "NONEXISTENT_SCHOOL",
        "academic_year" => "2026-2027"
      }

      assert {:error, "School not found with code: NONEXISTENT_SCHOOL"} =
               GroupUpdateProcessor.process_school_movement(record)
    end

    test "returns error when effective_date is malformed" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      school = school_fixture(%{code: "NEW_SCHOOL"})

      record = %{
        "student_id" => student.student_id,
        "school_code" => school.code,
        "academic_year" => "2026-2027",
        "effective_date" => "not-a-date"
      }

      assert {:error, "School movement failed: " <> _} =
               GroupUpdateProcessor.process_school_movement(record)
    end
  end

  describe "process_grade_update/1" do
    test "successfully processes grade update with valid data" do
      # Create fixtures
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      mapping_id = insert_active_mapping(student.id)
      grade = grade_fixture(%{number: 9998})

      # Get existing group for the grade
      grade_group = Dbservice.Groups.get_group_by_child_id_and_type(grade.id, "grade")

      # Create group user for the grade
      {:ok, _group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: grade_group.id
        })

      # Create enrollment record
      {:ok, _enrollment} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: grade_group.id,
          group_type: "grade",
          is_current: true,
          start_date: ~D[2024-01-01],
          academic_year: "2024-2025"
        })

      record = %{
        "student_id" => student.student_id,
        "grade" => grade.number
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:ok, "Grade update processed successfully"} = result

      assert Repo.query!(
               "SELECT end_reason FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
               [mapping_id]
             ).rows == [["student_grade_changed"]]
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "grade" => 10
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:error, "Student not found. student_id: \"NONEXISTENT_STUDENT\", apaar_id: nil"} =
               result
    end

    test "returns error when grade is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})

      record = %{
        "student_id" => student.student_id,
        "grade" => 999
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:error, "Grade not found with number: 999"} = result
    end

    test "returns error when grade group is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      grade = grade_fixture(%{number: 9999})

      record = %{
        "student_id" => student.student_id,
        "grade" => grade.number
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:error, "Group user or enrollment record not found"} = result
    end
  end

  describe "process_auth_group_update/1" do
    test "successfully processes auth group update with valid data" do
      # Create fixtures
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      auth_group = auth_group_fixture(%{name: "Test Auth Group"})

      # Get existing group for the auth group
      auth_group_group =
        Dbservice.Groups.get_group_by_child_id_and_type(auth_group.id, "auth_group")

      # Create group user for the auth group
      {:ok, _group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: auth_group_group.id
        })

      # Create enrollment record
      {:ok, _enrollment} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: auth_group.id,
          group_type: "auth_group",
          is_current: true,
          start_date: ~D[2024-01-01],
          academic_year: "2024-2025"
        })

      record = %{
        "student_id" => student.student_id,
        "auth_group_name" => auth_group.name
      }

      result = GroupUpdateProcessor.process_auth_group_update(record)

      assert {:ok, "Auth group update processed successfully"} = result
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "auth_group_name" => "Test Auth Group"
      }

      result = GroupUpdateProcessor.process_auth_group_update(record)

      assert {:error, "Student not found. student_id: \"NONEXISTENT_STUDENT\", apaar_id: nil"} =
               result
    end

    test "returns error when auth group is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})

      record = %{
        "student_id" => student.student_id,
        "auth_group_name" => "NONEXISTENT_AUTH_GROUP"
      }

      result = GroupUpdateProcessor.process_auth_group_update(record)

      assert {:error, "Auth group not found with name: NONEXISTENT_AUTH_GROUP"} = result
    end

    test "returns error when auth group group is not found" do
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      auth_group = auth_group_fixture(%{name: "Test Auth Group"})

      record = %{
        "student_id" => student.student_id,
        "auth_group_name" => auth_group.name
      }

      result = GroupUpdateProcessor.process_auth_group_update(record)

      assert {:error, "Group user or enrollment record not found"} = result
    end
  end

  defp insert_active_mapping(student_id) do
    mentor = user_fixture()
    school = school_fixture()

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('CSV Cleanup', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('CSV Cleanup', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[mapping_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_mentor_mentee_mappings
          (student_id, mentor_user_id, school_id, program_id, academic_year, started_at,
           assignment_source)
        VALUES ($1, $2, $3, $4, '2026-27', timezone('UTC', now()), 'af_lms')
        RETURNING id
        """,
        [student_id, mentor.id, school.id, program_id]
      ).rows

    mapping_id
  end
end
