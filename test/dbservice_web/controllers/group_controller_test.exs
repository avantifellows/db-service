defmodule DbserviceWeb.GroupControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.GroupsFixtures

  alias Dbservice.Groups.Group

  @create_attrs %{
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
  @update_attrs %{
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
  @valid_fields [
    "batch_contact_hours_per_week",
    "group_input_schema",
    "group_locale",
    "group_locale_data",
    "id",
    "name",
    "parent_id",
    "program_donor",
    "program_mode",
    "program_product_used",
    "program_start_date",
    "program_state",
    "program_sub_type",
    "program_target_outreach",
    "program_type",
    "type"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all group", %{conn: conn} do
      conn = get(conn, Routes.group_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create group" do
    test "renders group when data is valid", %{conn: conn} do
      conn = post(conn, Routes.group_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name",
               "type" => "group"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.group_path(conn, :create), group: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update group" do
    setup [:create_group]

    test "renders group when data is valid", %{conn: conn, group: %Group{id: id} = group} do
      conn = put(conn, Routes.group_path(conn, :update, group), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "type" => "group"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, group: group} do
      conn = put(conn, Routes.group_path(conn, :update, group), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete group" do
    setup [:create_group]

    test "deletes chosen group", %{conn: conn, group: group} do
      conn = delete(conn, Routes.group_path(conn, :delete, group))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.group_path(conn, :show, group))
      end
    end
  end

  defp create_group(_) do
    group = group_fixture()
    %{group: group}
  end
end
