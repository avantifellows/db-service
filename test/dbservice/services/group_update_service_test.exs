defmodule Dbservice.Services.GroupUpdateServiceTest do
  use Dbservice.DataCase

  alias Dbservice.Services.GroupUpdateService
  import Dbservice.UsersFixtures
  import Dbservice.GroupsFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.EnrollmentRecordFixtures

  describe "update_user_group_by_type/1" do
    test "successfully updates school group membership" do
      user = user_fixture()
      old_school = school_fixture()
      new_school = school_fixture()

      # Get the groups that were automatically created when schools were created
      old_group = Dbservice.Groups.get_group_by_child_id_and_type(old_school.id, "school")
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_school.id, "school")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: old_school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      params = %{
        "user_id" => user.id,
        "group_id" => new_group.id,
        "type" => "school"
      }

      result = GroupUpdateService.update_user_group_by_type(params)

      assert {:ok, updated_group_user} = result
      assert updated_group_user.group_id == new_group.id
      assert updated_group_user.user_id == user.id
    end

    test "successfully updates batch group membership with current_batch_pk" do
      user = user_fixture()
      old_batch = batch_fixture()
      new_batch = batch_fixture()

      # Get the groups that were automatically created when batches were created
      old_group = Dbservice.Groups.get_group_by_child_id_and_type(old_batch.id, "batch")
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_batch.id, "batch")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: old_batch.id,
          group_type: "batch",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      params = %{
        "user_id" => user.id,
        "group_id" => new_group.id,
        "type" => "batch",
        "current_batch_pk" => old_batch.id
      }

      result = GroupUpdateService.update_user_group_by_type(params)

      assert {:ok, updated_group_user} = result
      assert updated_group_user.group_id == new_group.id
      assert updated_group_user.user_id == user.id
    end

    test "returns error when group not found" do
      user = user_fixture()

      params = %{
        "user_id" => user.id,
        # Non-existent group ID
        "group_id" => 99999,
        "type" => "school"
      }

      result = GroupUpdateService.update_user_group_by_type(params)

      assert {:error, :not_found} = result
    end

    test "returns error when no group user exists for user and type" do
      user = user_fixture()
      school = school_fixture()
      new_school = school_fixture()

      # Get the group that was automatically created when the new school was created
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_school.id, "school")

      params = %{
        "user_id" => user.id,
        "group_id" => new_group.id,
        "type" => "school"
      }

      result = GroupUpdateService.update_user_group_by_type(params)

      assert {:error, :not_found} = result
    end

    test "returns error when no enrollment record exists" do
      user = user_fixture()
      old_school = school_fixture()
      new_school = school_fixture()

      # Get the groups that were automatically created when schools were created
      old_group = Dbservice.Groups.get_group_by_child_id_and_type(old_school.id, "school")
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_school.id, "school")

      # Create group user but no enrollment record
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_group.id
        })

      params = %{
        "user_id" => user.id,
        "group_id" => new_group.id,
        "type" => "school"
      }

      result = GroupUpdateService.update_user_group_by_type(params)

      assert {:error, :not_found} = result
    end
  end

  describe "find_records_to_update/4" do
    test "finds correct records for school type" do
      user = user_fixture()
      school = school_fixture()

      # Get the group that was automatically created when the school was created
      group = Dbservice.Groups.get_group_by_child_id_and_type(school.id, "school")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      group_users = [group_user]
      params = %{"user_id" => user.id, "group_id" => group.id, "type" => "school"}

      {found_group_user, found_enrollment_record} =
        GroupUpdateService.find_records_to_update(group_users, user.id, "school", params)

      assert found_group_user.id == group_user.id
      assert found_enrollment_record.id == enrollment_record.id
    end

    test "finds correct records for batch type with current_batch_pk" do
      user = user_fixture()
      batch = batch_fixture()

      # Get the group that was automatically created when the batch was created
      group = Dbservice.Groups.get_group_by_child_id_and_type(batch.id, "batch")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: batch.id,
          group_type: "batch",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      group_users = [group_user]
      group_users = Dbservice.Repo.preload(group_users, :group)
      params = %{"user_id" => user.id, "group_id" => group.id, "type" => "batch"}

      {found_group_user, found_enrollment_record} =
        GroupUpdateService.find_records_to_update(group_users, user.id, "batch", params)

      assert found_group_user.id == group_user.id
      assert found_enrollment_record.id == enrollment_record.id
    end
  end

  describe "find_group_user_to_update/3" do
    test "returns first group user for non-batch types" do
      user = user_fixture()
      school1 = school_fixture()
      school2 = school_fixture()

      # Get the groups that were automatically created when schools were created
      group1 = Dbservice.Groups.get_group_by_child_id_and_type(school1.id, "school")
      group2 = Dbservice.Groups.get_group_by_child_id_and_type(school2.id, "school")

      # Create multiple group users
      {:ok, group_user1} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group1.id
        })

      {:ok, group_user2} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group2.id
        })

      group_users = [group_user1, group_user2]
      params = %{}

      result = GroupUpdateService.find_group_user_to_update(group_users, "school", params)

      assert result.id == group_user1.id
    end

    test "returns specific group user for batch type with current_batch_pk" do
      user = user_fixture()
      batch1 = batch_fixture()
      batch2 = batch_fixture()

      # Get the groups that were automatically created when batches were created
      group1 = Dbservice.Groups.get_group_by_child_id_and_type(batch1.id, "batch")
      group2 = Dbservice.Groups.get_group_by_child_id_and_type(batch2.id, "batch")

      # Create group users
      {:ok, group_user1} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group1.id
        })

      {:ok, group_user2} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group2.id
        })

      # Preload the group associations
      group_users = Dbservice.Repo.preload([group_user1, group_user2], :group)
      params = %{"current_batch_pk" => batch2.id}

      result = GroupUpdateService.find_group_user_to_update(group_users, "batch", params)

      assert result.id == group_user2.id
    end

    test "returns nil when no matching group user found for batch" do
      user = user_fixture()
      batch1 = batch_fixture()
      batch2 = batch_fixture()

      # Get the group that was automatically created when batch1 was created
      group1 = Dbservice.Groups.get_group_by_child_id_and_type(batch1.id, "batch")

      # Create group user
      {:ok, group_user1} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group1.id
        })

      # Preload the group association
      group_users = Dbservice.Repo.preload([group_user1], :group)
      # Non-matching batch ID
      params = %{"current_batch_pk" => batch2.id}

      result = GroupUpdateService.find_group_user_to_update(group_users, "batch", params)

      assert is_nil(result)
    end
  end

  describe "find_enrollment_record/3" do
    test "finds enrollment record for non-batch types" do
      user = user_fixture()
      school = school_fixture()

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      params = %{}

      result = GroupUpdateService.find_enrollment_record(user.id, "school", params)

      assert result.id == enrollment_record.id
      assert result.user_id == user.id
      assert result.group_type == "school"
      assert result.is_current == true
    end

    test "finds enrollment record for batch type with current_batch_pk" do
      user = user_fixture()
      batch = batch_fixture()

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: batch.id,
          group_type: "batch",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      params = %{"current_batch_pk" => batch.id}

      result = GroupUpdateService.find_enrollment_record(user.id, "batch", params)

      assert result.id == enrollment_record.id
      assert result.user_id == user.id
      assert result.group_type == "batch"
      assert result.group_id == batch.id
    end

    test "returns nil when no enrollment record found" do
      user = user_fixture()

      params = %{}

      result = GroupUpdateService.find_enrollment_record(user.id, "school", params)

      assert is_nil(result)
    end

    test "returns nil when enrollment record is not current" do
      user = user_fixture()
      school = school_fixture()

      # Create non-current enrollment record
      {:ok, _enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          # Not current
          is_current: false
        })

      params = %{}

      result = GroupUpdateService.find_enrollment_record(user.id, "school", params)

      assert is_nil(result)
    end
  end

  describe "update_group_user_and_enrollment/4" do
    test "successfully updates both group user and enrollment record" do
      user = user_fixture()
      old_school = school_fixture()
      new_school = school_fixture()

      # Get the groups that were automatically created when schools were created
      old_group = Dbservice.Groups.get_group_by_child_id_and_type(old_school.id, "school")
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_school.id, "school")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: old_group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: old_school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      params = %{"group_id" => new_group.id}

      result =
        GroupUpdateService.update_group_user_and_enrollment(
          group_user,
          enrollment_record,
          params,
          new_school.id
        )

      assert {:ok, updated_group_user} = result
      assert updated_group_user.group_id == new_group.id

      # Verify enrollment record was updated
      updated_enrollment_record =
        Dbservice.Repo.get!(
          Dbservice.EnrollmentRecords.EnrollmentRecord,
          enrollment_record.id
        )

      assert updated_enrollment_record.group_id == new_school.id
    end

    test "rolls back transaction when enrollment record update fails" do
      user = user_fixture()
      school = school_fixture()

      # Get the group that was automatically created when the school was created
      group = Dbservice.Groups.get_group_by_child_id_and_type(school.id, "school")

      # Create group user
      {:ok, group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group.id
        })

      # Create enrollment record
      {:ok, enrollment_record} =
        Dbservice.EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: school.id,
          group_type: "school",
          academic_year: "2024-25",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      # Use invalid enrollment record data to cause failure
      params = %{"group_id" => group.id}

      result =
        GroupUpdateService.update_group_user_and_enrollment(
          group_user,
          enrollment_record,
          params,
          # Invalid group_id for enrollment record
          nil
        )

      assert {:error, _failed_operation} = result

      # Verify no changes were made (transaction rolled back)
      unchanged_group_user = Dbservice.Repo.get!(Dbservice.Groups.GroupUser, group_user.id)
      assert unchanged_group_user.group_id == group.id

      unchanged_enrollment_record =
        Dbservice.Repo.get!(
          Dbservice.EnrollmentRecords.EnrollmentRecord,
          enrollment_record.id
        )

      assert unchanged_enrollment_record.group_id == school.id
    end
  end
end
