defmodule Dbservice.DataImport.GroupUpdateProcessorTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport.GroupUpdateProcessor
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
          academic_year: "2024-25"
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

      assert {:error, "Student not found with ID: NONEXISTENT_STUDENT"} = result
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
          academic_year: "2024-25"
        })

      record = %{
        "student_id" => student.student_id,
        "school_code" => school.code
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:ok, "School update processed successfully"} = result
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "school_code" => "SCHOOL001"
      }

      result = GroupUpdateProcessor.process_school_update(record)

      assert {:error, "Student not found with ID: NONEXISTENT_STUDENT"} = result
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

  describe "process_grade_update/1" do
    test "successfully processes grade update with valid data" do
      # Create fixtures
      {user, student} = student_fixture(%{student_id: "STUDENT001"})
      grade = grade_fixture(%{number: 10})

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
          academic_year: "2024-25"
        })

      record = %{
        "student_id" => student.student_id,
        "grade" => grade.number
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:ok, "Grade update processed successfully"} = result
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "grade" => 10
      }

      result = GroupUpdateProcessor.process_grade_update(record)

      assert {:error, "Student not found with ID: NONEXISTENT_STUDENT"} = result
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
      grade = grade_fixture(%{number: 10})

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
          academic_year: "2024-25"
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

      assert {:error, "Student not found with ID: NONEXISTENT_STUDENT"} = result
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
end
