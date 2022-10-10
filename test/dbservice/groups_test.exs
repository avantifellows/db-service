defmodule Dbservice.GroupsTest do
  use Dbservice.DataCase

  alias Dbservice.Groups

  describe "group" do
    alias Dbservice.Groups.Group

    import Dbservice.GroupsFixtures

    @invalid_attrs %{
      name: nil,
      type: nil,
      program_type: nil,
      program_sub_type: nil,
      program_mode: nil,
      program_start_date: nil,
      program_target_outreach: nil,
      program_donor: nil,
      program_state: nil,
      batch_contact_hours_per_week: nil,
      group_input_schema: nil,
      group_locale: nil,
      group_locale_data: nil
    }

    test "list_group/0 returns all group" do
      group = group_fixture()

      [group_list] =
        Enum.filter(
          Groups.list_group(),
          fn t -> t.program_type == group.program_type end
        )

      assert group_list.program_type == group.program_type
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Groups.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{
        name: "some name",
        type: "group",
        program_type: "some program type",
        program_sub_type: "some program subtype",
        program_mode: "some program mode",
        program_start_date: ~U[2022-04-28 13:58:00Z],
        program_target_outreach: Enum.random(3000..9999),
        program_donor: "some program donor",
        program_state: "some program state",
        batch_contact_hours_per_week: Enum.random(20..48),
        group_input_schema: %{},
        group_locale: "some locale",
        group_locale_data: %{}
      }

      assert {:ok, %Group{} = group} = Groups.create_group(valid_attrs)
      assert group.name == "some name"
      assert group.program_type == "some program type"
      assert group.program_sub_type == "some program subtype"
      assert group.program_mode == "some program mode"
      assert group.program_donor == "some program donor"
      assert group.program_state == "some program state"
      assert group.group_input_schema == %{}
      assert group.group_locale == "some locale"
      assert group.group_locale_data == %{}
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()

      update_attrs = %{
        name: "some updated name",
        type: "group",
        program_type: "some updated program type",
        program_sub_type: "some updated program subtype",
        program_mode: "some updated program mode",
        program_start_date: ~U[2022-04-28 13:58:00Z],
        program_target_outreach: Enum.random(3000..9999),
        program_donor: "some updated program donor",
        program_state: "some updated program state",
        batch_contact_hours_per_week: Enum.random(20..48),
        group_input_schema: %{},
        group_locale: "some updated locale",
        group_locale_data: %{}
      }

      assert {:ok, %Group{} = group} = Groups.update_group(group, update_attrs)
      assert group.name == "some updated name"
      assert group.program_type == "some updated program type"
      assert group.program_sub_type == "some updated program subtype"
      assert group.program_mode == "some updated program mode"
      assert group.program_donor == "some updated program donor"
      assert group.program_state == "some updated program state"
      assert group.group_input_schema == %{}
      assert group.group_locale == "some updated locale"
      assert group.group_locale_data == %{}
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
