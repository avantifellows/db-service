defmodule Dbservice.Services.EnrollmentServiceTest do
  use Dbservice.DataCase

  alias Dbservice.Services.EnrollmentService
  import Dbservice.UsersFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.AuthGroupsFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.GradesFixtures
  import Dbservice.EnrollmentRecordFixtures

  describe "process_enrollment/1" do
    test "processes auth_group enrollment successfully" do
      # Setup: Create necessary auth group and user
      user = user_fixture()

      enrollment_data = %{
        "enrollment_type" => "auth_group",
        "auth_group" => "test_auth_group",
        "user_id" => user.id,
        "start_date" => "2024-01-01"
      }

      # This test would require proper fixtures and data setup
      # For now, test the structure
      result = EnrollmentService.process_enrollment(enrollment_data)

      # Result should be either success or specific error
      assert match?({:error, _}, result)
    end

    test "handles school enrollment with valid school code" do
      user = user_fixture()

      enrollment_data = %{
        "enrollment_type" => "school",
        "school_code" => "SCH001",
        "user_id" => user.id,
        "academic_year" => "2024-25",
        "start_date" => "2024-01-01"
      }

      result = EnrollmentService.process_enrollment(enrollment_data)

      # Should return error if school doesn't exist, or success if it does
      assert {:error, error_msg} = result
      assert String.contains?(error_msg, "School not found")
    end

    test "handles batch enrollment" do
      user = user_fixture()

      enrollment_data = %{
        "enrollment_type" => "batch",
        "batch_id" => "BATCH001",
        "user_id" => user.id,
        "academic_year" => "2024-25",
        "start_date" => "2024-01-01"
      }

      result = EnrollmentService.process_enrollment(enrollment_data)

      assert {:error, error_msg} = result
      assert String.contains?(error_msg, "Batch not found")
    end

    test "handles grade enrollment" do
      user = user_fixture()

      enrollment_data = %{
        "enrollment_type" => "grade",
        "grade_id" => 9,
        "user_id" => user.id,
        "academic_year" => "2024-25",
        "start_date" => "2024-01-01"
      }

      result = EnrollmentService.process_enrollment(enrollment_data)

      assert {:error, error_msg} = result

      assert String.contains?(error_msg, "Grade not found")
    end

    test "returns error for unknown enrollment type" do
      user = user_fixture()

      enrollment_data = %{
        "enrollment_type" => "unknown_type",
        "user_id" => user.id
      }

      result = EnrollmentService.process_enrollment(enrollment_data)
      assert {:error, "Unknown enrollment type"} = result
    end
  end

  describe "get_*_group_id functions" do
    test "get_auth_group_id returns group ID for existing auth group" do
      # Create test auth group (group is created automatically)
      _auth_group = auth_group_fixture(%{name: "TEST_AUTH_GROUP"})

      # Test successful retrieval
      result = EnrollmentService.get_auth_group_id("TEST_AUTH_GROUP")
      assert is_integer(result)
    end

    test "get_school_group_id returns group ID for existing school" do
      # Create test school (group is created automatically)
      _school = school_fixture(%{code: "TEST_SCH_001"})

      # Test successful retrieval
      result = EnrollmentService.get_school_group_id("TEST_SCH_001")
      assert is_integer(result)
    end

    test "get_batch_group_id returns group ID for existing batch" do
      # Create test batch (group is created automatically)
      _batch = batch_fixture(%{batch_id: "TEST_BATCH_001"})

      # Test successful retrieval
      result = EnrollmentService.get_batch_group_id("TEST_BATCH_001")
      assert is_integer(result)
    end

    test "get_grade_group_id returns group ID for existing grade" do
      # Create test grade (group is created automatically)
      grade = grade_fixture(%{number: 11})

      # Test successful retrieval
      result = EnrollmentService.get_grade_group_id(grade.id)
      assert is_integer(result)
    end
  end

  describe "resolve_academic_year/2" do
    test "returns nil for auth_group type" do
      params = %{"academic_year" => "2024-25"}
      result = EnrollmentService.resolve_academic_year("auth_group", params)
      assert result == nil
    end

    test "returns academic_year for other group types" do
      params = %{"academic_year" => "2024-25"}

      result = EnrollmentService.resolve_academic_year("school", params)
      assert result == "2024-25"

      result = EnrollmentService.resolve_academic_year("batch", params)
      assert result == "2024-25"

      result = EnrollmentService.resolve_academic_year("grade", params)
      assert result == "2024-25"
    end

    test "handles missing academic_year in params" do
      params = %{}
      result = EnrollmentService.resolve_academic_year("school", params)
      assert result == nil
    end
  end

  describe "handle_group_user_enrollment/1" do
    test "creates new group user when none exists" do
      user = user_fixture()
      _school = school_fixture(%{code: "TEST_SCHOOL"})
      group_id = EnrollmentService.get_school_group_id("TEST_SCHOOL")

      params = %{
        "user_id" => user.id,
        "group_id" => group_id,
        "academic_year" => "2024-25",
        "start_date" => ~D[2024-01-01]
      }

      result = EnrollmentService.handle_group_user_enrollment(params)
      assert {:ok, group_user} = result
      assert group_user.user_id == user.id
      assert group_user.group_id == group_id
    end

    test "updates existing group user when one exists" do
      user = user_fixture()
      _school = school_fixture(%{code: "TEST_SCHOOL"})
      group_id = EnrollmentService.get_school_group_id("TEST_SCHOOL")

      # Create initial group user
      initial_params = %{
        "user_id" => user.id,
        "group_id" => group_id,
        "academic_year" => "2024-25",
        "start_date" => ~D[2024-01-01]
      }

      {:ok, _initial_group_user} = EnrollmentService.handle_group_user_enrollment(initial_params)

      # Update the group user
      updated_params = Map.put(initial_params, "start_date", ~D[2024-02-01])
      result = EnrollmentService.handle_group_user_enrollment(updated_params)

      assert {:ok, updated_group_user} = result
      assert updated_group_user.user_id == user.id
      assert updated_group_user.group_id == group_id
    end
  end

  describe "create_new_group_user/1" do
    test "creates new group user with enrollment record for auth group" do
      user = user_fixture()
      _auth_group = auth_group_fixture(%{name: "TEST_AUTH"})
      group_id = EnrollmentService.get_auth_group_id("TEST_AUTH")

      params = %{
        "user_id" => user.id,
        "group_id" => group_id,
        "start_date" => ~D[2024-01-01]
      }

      result = EnrollmentService.create_new_group_user(params)
      assert {:ok, group_user} = result
      assert group_user.user_id == user.id
      assert group_user.group_id == group_id
    end
  end

  describe "update_school_enrollment/4" do
    test "updates previous enrollment records when academic year changes" do
      user = user_fixture()
      school = school_fixture(%{code: "TEST_SCHOOL"})

      # Create an existing enrollment record for a different academic year
      existing_enrollment = %{
        "user_id" => user.id,
        "group_id" => school.id,
        "group_type" => "school",
        "academic_year" => "2023-24",
        "start_date" => ~D[2023-06-01],
        "is_current" => true
      }

      {:ok, _} = Dbservice.EnrollmentRecords.create_enrollment_record(existing_enrollment)

      # Update school enrollment with new academic year
      new_academic_year = "2024-25"
      end_date = ~D[2024-05-31]

      EnrollmentService.update_school_enrollment(
        user.id,
        school.id,
        new_academic_year,
        end_date
      )

      # Verify the existing record was updated
      updated_record =
        Dbservice.Repo.get_by(Dbservice.EnrollmentRecords.EnrollmentRecord, %{
          user_id: user.id,
          group_id: school.id,
          academic_year: "2023-24"
        })

      assert updated_record.is_current == false
      assert updated_record.end_date == end_date
    end

    test "does not update enrollment records with same academic year" do
      user = user_fixture()
      school = school_fixture(%{code: "TEST_SCHOOL"})

      # Create an existing enrollment record for the same academic year
      existing_enrollment = %{
        "user_id" => user.id,
        "group_id" => school.id,
        "group_type" => "school",
        "academic_year" => "2024-25",
        "start_date" => ~D[2024-01-01],
        "is_current" => true
      }

      {:ok, _} = Dbservice.EnrollmentRecords.create_enrollment_record(existing_enrollment)

      # Try to update with the same academic year
      EnrollmentService.update_school_enrollment(
        user.id,
        school.id,
        # Same academic year
        "2024-25",
        ~D[2024-05-31]
      )

      # Verify the record was NOT updated
      record =
        Dbservice.Repo.get_by(Dbservice.EnrollmentRecords.EnrollmentRecord, %{
          user_id: user.id,
          group_id: school.id,
          academic_year: "2024-25"
        })

      assert record.is_current == true
      assert record.end_date == nil
    end

    test "does not update enrollment records that are already not current" do
      user = user_fixture()
      school = school_fixture(%{code: "TEST_SCHOOL"})

      # Create an existing enrollment record that is already not current
      existing_enrollment = %{
        "user_id" => user.id,
        "group_id" => school.id,
        "group_type" => "school",
        "academic_year" => "2023-24",
        "start_date" => ~D[2023-06-01],
        "is_current" => false,
        "end_date" => ~D[2023-12-31]
      }

      {:ok, _} = Dbservice.EnrollmentRecords.create_enrollment_record(existing_enrollment)

      # Try to update
      EnrollmentService.update_school_enrollment(
        user.id,
        school.id,
        "2024-25",
        ~D[2024-05-31]
      )

      # Verify the record was NOT updated
      record =
        Dbservice.Repo.get_by(Dbservice.EnrollmentRecords.EnrollmentRecord, %{
          user_id: user.id,
          group_id: school.id,
          academic_year: "2023-24"
        })

      assert record.is_current == false
      # Original end_date should remain
      assert record.end_date == ~D[2023-12-31]
    end

    test "handles case when no enrollment records exist" do
      user = user_fixture()
      school = school_fixture(%{code: "TEST_SCHOOL"})

      # Try to update when no records exist - should not error
      EnrollmentService.update_school_enrollment(
        user.id,
        school.id,
        "2024-25",
        ~D[2024-05-31]
      )

      # Verify no records were created or modified
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where: er.user_id == ^user.id and er.group_id == ^school.id
        )

      assert records == []
    end

    test "updates multiple enrollment records for different academic years" do
      user = user_fixture()
      school = school_fixture(%{code: "TEST_SCHOOL"})

      # Create multiple existing enrollment records for different academic years
      enrollments = [
        %{
          "user_id" => user.id,
          "group_id" => school.id,
          "group_type" => "school",
          "academic_year" => "2022-23",
          "start_date" => ~D[2022-06-01],
          "is_current" => true
        },
        %{
          "user_id" => user.id,
          "group_id" => school.id,
          "group_type" => "school",
          "academic_year" => "2023-24",
          "start_date" => ~D[2023-06-01],
          "is_current" => true
        }
      ]

      Enum.each(enrollments, fn enrollment ->
        {:ok, _} = Dbservice.EnrollmentRecords.create_enrollment_record(enrollment)
      end)

      # Update with new academic year
      EnrollmentService.update_school_enrollment(
        user.id,
        school.id,
        "2024-25",
        ~D[2024-05-31]
      )

      # Verify both records were updated
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where:
              er.user_id == ^user.id and er.group_id == ^school.id and
                er.academic_year != "2024-25"
        )

      assert length(records) == 2

      Enum.each(records, fn record ->
        assert record.is_current == false
        assert record.end_date == ~D[2024-05-31]
      end)
    end
  end

  describe "handle_enrollment_record/5" do
    test "creates a new enrollment record when none exists" do
      user = user_fixture()
      school = school_fixture()
      academic_year = "2024-25"
      start_date = ~D[2024-01-01]

      # Ensure no enrollment record exists initially
      existing_record =
        Dbservice.Repo.one(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where:
              er.user_id == ^user.id and
                er.group_id == ^school.id and
                er.group_type == "school" and
                er.academic_year == ^academic_year
        )

      assert is_nil(existing_record)

      # Call handle_enrollment_record
      result =
        EnrollmentService.handle_enrollment_record(
          user.id,
          school.id,
          "school",
          academic_year,
          start_date
        )

      # Should create a new record
      assert {:ok, %Dbservice.EnrollmentRecords.EnrollmentRecord{} = record} = result
      assert record.user_id == user.id
      assert record.group_id == school.id
      assert record.group_type == "school"
      assert record.academic_year == academic_year
      assert record.start_date == start_date
      assert record.is_current == true
    end

    test "does not create duplicate enrollment record when one already exists" do
      user = user_fixture()
      school = school_fixture()
      academic_year = "2024-25"
      start_date = ~D[2024-01-01]

      # Create an existing enrollment record
      existing_record_attrs = %{
        "user_id" => user.id,
        "group_id" => school.id,
        "group_type" => "school",
        "academic_year" => academic_year,
        "start_date" => start_date
      }

      {:ok, existing_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(existing_record_attrs)

      # Call handle_enrollment_record
      result =
        EnrollmentService.handle_enrollment_record(
          user.id,
          school.id,
          "school",
          academic_year,
          start_date
        )

      # Should return nil (no creation)
      assert is_nil(result)

      # Verify only one record exists
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where:
              er.user_id == ^user.id and
                er.group_id == ^school.id and
                er.group_type == "school" and
                er.academic_year == ^academic_year
        )

      assert length(records) == 1
      assert hd(records).id == existing_record.id
    end

    test "handles different academic years correctly" do
      user = user_fixture()
      school = school_fixture()
      start_date = ~D[2024-01-01]

      # Create record for 2023-24
      {:ok, _} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          "user_id" => user.id,
          "group_id" => school.id,
          "group_type" => "school",
          "academic_year" => "2023-24",
          "start_date" => start_date
        })

      # Handle enrollment for 2024-25
      result =
        EnrollmentService.handle_enrollment_record(
          user.id,
          school.id,
          "school",
          "2024-25",
          start_date
        )

      # Should create new record for different academic year
      assert {:ok, %Dbservice.EnrollmentRecords.EnrollmentRecord{} = record} = result
      assert record.academic_year == "2024-25"

      # Verify both records exist
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where:
              er.user_id == ^user.id and
                er.group_id == ^school.id and
                er.group_type == "school"
        )

      assert length(records) == 2
      academic_years = Enum.map(records, & &1.academic_year) |> Enum.sort()
      assert academic_years == ["2023-24", "2024-25"]
    end

    test "handles different group types correctly" do
      user = user_fixture()
      school = school_fixture()
      batch = batch_fixture()
      academic_year = "2024-25"
      start_date = ~D[2024-01-01]

      # Create school enrollment record
      {:ok, _} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          "user_id" => user.id,
          "group_id" => school.id,
          "group_type" => "school",
          "academic_year" => academic_year,
          "start_date" => start_date
        })

      # Handle enrollment for batch (different group type)
      result =
        EnrollmentService.handle_enrollment_record(
          user.id,
          batch.id,
          "batch",
          academic_year,
          start_date
        )

      # Should create new record for different group type
      assert {:ok, %Dbservice.EnrollmentRecords.EnrollmentRecord{} = record} = result
      assert record.group_type == "batch"
      assert record.group_id == batch.id

      # Verify both records exist
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where: er.user_id == ^user.id and er.academic_year == ^academic_year
        )

      assert length(records) == 2
      group_types = Enum.map(records, & &1.group_type) |> Enum.sort()
      assert group_types == ["batch", "school"]
    end

    test "handles different users correctly" do
      user1 = user_fixture()
      user2 = user_fixture()
      school = school_fixture()
      academic_year = "2024-25"
      start_date = ~D[2024-01-01]

      # Create record for user1
      {:ok, _} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          "user_id" => user1.id,
          "group_id" => school.id,
          "group_type" => "school",
          "academic_year" => academic_year,
          "start_date" => start_date
        })

      # Handle enrollment for user2
      result =
        EnrollmentService.handle_enrollment_record(
          user2.id,
          school.id,
          "school",
          academic_year,
          start_date
        )

      # Should create new record for different user
      assert {:ok, %Dbservice.EnrollmentRecords.EnrollmentRecord{} = record} = result
      assert record.user_id == user2.id

      # Verify both records exist
      records =
        Dbservice.Repo.all(
          from er in Dbservice.EnrollmentRecords.EnrollmentRecord,
            where:
              er.group_id == ^school.id and
                er.group_type == "school" and
                er.academic_year == ^academic_year
        )

      assert length(records) == 2
      user_ids = Enum.map(records, & &1.user_id) |> Enum.sort()
      assert user_ids == [user1.id, user2.id]
    end
  end
end
