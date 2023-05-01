defmodule Dbservice.GroupsTest do
  use Dbservice.DataCase

  alias Dbservice.Groups

  describe "group" do
    alias Dbservice.Groups.Group

    import Dbservice.GroupsFixtures

    @invalid_attrs %{
      name: nil,
      input_schema: nil,
      locale: nil,
      locale_data: nil
    }

    test "list_group/0 returns all group" do
      group = group_fixture()
      [head | _tail] = Groups.list_group()
      assert Map.keys(head) == Map.keys(group)
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Groups.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{
        name: "some name",
        input_schema: %{},
        locale: "some locale",
        locale_data: %{
          "some locale" => %{
            "title" => "Some title"
          }
        }
      }

      assert {:ok, %Group{} = group} = Groups.create_group(valid_attrs)
      assert group.name == "some name"
      assert group.input_schema == %{}
      assert group.locale == "some locale"

      assert group.locale_data == %{
               "some locale" => %{
                 "title" => "Some title"
               }
             }
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()

      update_attrs = %{
        name: "some updated name",
        input_schema: %{},
        locale: "some updated locale",
        locale_data: %{
          "some updated locale" => %{
            "title" => "Some updated title"
          }
        }
      }

      assert {:ok, %Group{} = group} = Groups.update_group(group, update_attrs)
      assert group.name == "some updated name"
      assert group.input_schema == %{}
      assert group.locale == "some updated locale"

      assert group.locale_data == %{
               "some updated locale" => %{
                 "title" => "Some updated title"
               }
             }
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
  end
end
