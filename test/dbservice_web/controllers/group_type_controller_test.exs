defmodule DbserviceWeb.GroupTypeControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.GroupTypesFixtures

  alias Dbservice.Groups.GroupType

  @create_attrs %{
    type: "some type",
    child_id: Enum.random(1..100)
  }
  @update_attrs %{
    type: "some updated type",
    child_id: Enum.random(1..100)
  }
  @invalid_attrs %{
    type: nil,
    child_id: nil
  }
  @valid_fields [
    "child_id",
    "id",
    "type"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all group types", %{conn: conn} do
      conn = get(conn, Routes.group_type_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create group type" do
    test "renders group type when data is valid", %{conn: conn} do
      conn = post(conn, Routes.group_type_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.group_type_path(conn, :show, id))

      assert %{"id" => ^id, "type" => "some type", "child_id" => child_id} =
               json_response(conn, 200)

      assert Enum.member?(1..100, child_id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.group_type_path(conn, :create), group_type: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update group type" do
    setup [:create_group_type]

    test "renders group type when data is valid", %{
      conn: conn,
      group_type: %GroupType{id: id} = group_type
    } do
      conn = put(conn, Routes.group_type_path(conn, :update, group_type), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.group_type_path(conn, :show, id))

      assert %{"id" => ^id, "type" => "some updated type", "child_id" => child_id} =
               json_response(conn, 200)

      assert Enum.member?(1..100, child_id)
    end

    test "renders errors when data is invalid", %{conn: conn, group_type: group_type} do
      conn = put(conn, Routes.group_type_path(conn, :update, group_type), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete group type" do
    setup [:create_group_type]

    test "deletes chosen group type", %{conn: conn, group_type: group_type} do
      conn = delete(conn, Routes.group_type_path(conn, :delete, group_type))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.group_type_path(conn, :show, group_type))
      end
    end
  end

  defp create_group_type(_) do
    group_type = group_type_fixture()
    %{group_type: group_type}
  end
end
