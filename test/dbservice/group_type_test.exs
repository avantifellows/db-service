defmodule Dbservice.GroupTypeTest do
  use Dbservice.DataCase

  alias Dbservice.GroupTypes

  describe "group type" do
    alias Dbservice.Groups.GroupType

    import Dbservice.GroupTypesFixtures

    @invalid_attrs %{
      type: nil,
      child_id: nil
    }

    test "list_group_type/0 returns all group types" do
      group_type = group_type_fixture()
      [head | _tail] = GroupTypes.list_group_type()
      # IO.inspect(GroupType.list_group_type())
      assert Map.keys(head) == Map.keys(group_type)
    end

    test "get_group_type!/1 returns the group type with given id" do
      group_type = group_type_fixture()
      assert GroupTypes.get_group_type!(group_type.id) == group_type
    end

    test "create_group_type/1 with valid data creates a group type" do
      valid_attrs = %{
        type: "some type",
        child_id: Enum.random(1..100)
      }

      assert {:ok, %GroupType{} = group_type} = GroupTypes.create_group_type(valid_attrs)
      assert group_type.type == "some type"
      assert group_type.child_id == valid_attrs[:child_id]
    end

    test "create_group_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = GroupTypes.create_group_type(@invalid_attrs)
    end

    test "update_group_type/2 with valid data updates the group type" do
      group_type = group_type_fixture()

      update_attrs = %{
        type: "some updated type",
        child_id: Enum.random(1..100)
      }

      assert {:ok, %GroupType{} = group_type} =
               GroupTypes.update_group_type(group_type, update_attrs)

      assert group_type.type == "some updated type"
      assert group_type.child_id == update_attrs[:child_id]
    end

    test "update_group_type/2 with invalid data returns error changeset" do
      group_type = group_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               GroupTypes.update_group_type(group_type, @invalid_attrs)

      assert group_type == GroupTypes.get_group_type!(group_type.id)
    end

    test "delete_group_type/1 deletes the group type" do
      group_type = group_type_fixture()
      assert {:ok, %GroupType{}} = GroupTypes.delete_group_type(group_type)
      assert_raise Ecto.NoResultsError, fn -> GroupTypes.get_group_type!(group_type.id) end
    end

    test "change_group_type/1 returns a group type changeset" do
      group_type = group_type_fixture()
      assert %Ecto.Changeset{} = GroupTypes.change_group_type(group_type)
    end
  end
end
