defmodule Dbservice.GroupsTest do
  use Dbservice.DataCase

  alias Dbservice.Groups

  describe "group" do
    alias Dbservice.Groups.Group
    import Dbservice.GroupsFixtures
    import Dbservice.UsersFixtures
    import Dbservice.SessionsFixtures

    @invalid_attrs %{
      type: nil,
      child_id: nil
    }
    test "list_group/0 returns all groups" do
      group = group_fixture()
      groups = Groups.list_group()
      assert Enum.any?(groups, fn g -> g.id == group.id end)
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Groups.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{
        type: "some type",
        child_id: 123
      }

      assert {:ok, %Group{} = group} = Groups.create_group(valid_attrs)
      assert group.type == "some type"
      assert group.child_id == 123
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()

      update_attrs = %{
        type: "updated type",
        child_id: 456
      }

      assert {:ok, %Group{} = group} = Groups.update_group(group, update_attrs)
      assert group.type == "updated type"
      assert group.child_id == 456
      assert group.id == group.id
    end

    test "update_group/2 with invalid data returns error changeset" do
      group = group_fixture()
      assert {:error, %Ecto.Changeset{}} = Groups.update_group(group, @invalid_attrs)
      assert group == Groups.get_group!(group.id)
    end

    test "delete_group/1 deletes the group" do
      group = group_fixture()
      assert {:ok, %Group{}} = Groups.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Groups.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset" do
      group = group_fixture()
      assert %Ecto.Changeset{} = Groups.change_group(group)
    end

    test "get_group_by_child_id_and_type/2 returns the group with given child_id and type" do
      group = group_fixture()
      assert Groups.get_group_by_child_id_and_type(group.child_id, group.type) == group
    end

    test "get_group_by_child_id_and_type/2 returns nil if no group found" do
      assert Groups.get_group_by_child_id_and_type(999, "nonexistent") == nil
    end

    test "get_group_by_group_id_and_type/2 returns the group with given group_id and type" do
      group = group_fixture()
      assert Groups.get_group_by_group_id_and_type(group.id, group.type) == group
    end

    test "get_group_by_group_id_and_type/2 returns nil if no group found" do
      assert Groups.get_group_by_group_id_and_type(999, "nonexistent") == nil
    end

    test "update_users/2 updates the user mapped to a group" do
      group = group_fixture()

      group_id = group.id
      user1 = user_fixture()
      user2 = user_fixture()
      user_ids = [user1.id, user2.id]

      assert {:ok, group} = Groups.update_users(group.id, user_ids)
      assert group.id == group_id
      updated_group = Repo.preload(group, :user)
      assert Enum.map(updated_group.user, & &1.id) == user_ids
    end

    test "update_users/2 with empty list removes all users from the group" do
      group = group_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      user_ids = [user1.id, user2.id]

      {:ok, _} = Groups.update_users(group.id, user_ids)

      assert {:ok, group} = Groups.update_users(group.id, [])
      updated_group = Repo.preload(group, :user)
      assert Enum.empty?(updated_group.user)
    end

    test "update_sessions/2 updates the sessions mapped to a group" do
      group = group_fixture()

      group_id = group.id
      session1 = session_fixture()
      session2 = session_fixture()
      session_ids = [session1.id, session2.id]

      assert {:ok, group} = Groups.update_sessions(group.id, session_ids)
      assert group.id == group_id
      updated_group = Repo.preload(group, :session)
      assert Enum.map(updated_group.session, & &1.id) == session_ids
    end

    test "update_sessions/2 with empty list removes all sessions from the group" do
      group = group_fixture()
      session1 = session_fixture()
      session2 = session_fixture()
      session_ids = [session1.id, session2.id]

      {:ok, _} = Groups.update_sessions(group.id, session_ids)

      assert {:ok, group} = Groups.update_sessions(group.id, [])
      updated_group = Repo.preload(group, :session)
      assert Enum.empty?(updated_group.session)
    end
  end
end
