defmodule DbserviceWeb.GroupControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.GroupsFixtures

  alias Dbservice.Groups.Group

  @create_attrs %{
    type: "generic",
    child_id: 42
  }
  @update_attrs %{
    type: "custom",
    child_id: 43
  }
  @invalid_attrs %{
    type: nil,
    child_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all groups with data", %{conn: conn} do
      group = group_fixture()
      conn = get(conn, ~p"/api/group")
      response = json_response(conn, 200)
      assert Enum.any?(response, fn g -> g["id"] == group.id end)
      found_group = Enum.find(response, fn g -> g["id"] == group.id end)
      assert found_group["type"] == group.type
      assert found_group["child_id"] == group.child_id
    end
  end

  describe "create group" do
    test "renders group when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/group", @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/group/#{id}")

      assert %{
               "id" => ^id,
               "type" => "generic",
               "child_id" => 42
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/group", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show group" do
    setup [:create_group]

    test "renders group", %{conn: conn, group: %Group{id: id}} do
      conn = get(conn, ~p"/api/group/#{id}")

      assert %{
               "id" => ^id,
               "type" => "some type",
               "child_id" => 1
             } = json_response(conn, 200)
    end

    test "renders 404 when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/group/123456")
      end
    end
  end

  describe "update group" do
    setup [:create_group]

    test "renders group when data is valid", %{conn: conn, group: %Group{id: id}} do
      conn = put(conn, ~p"/api/group/#{id}", @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/group/#{id}")

      assert %{
               "id" => ^id,
               "type" => "custom",
               "child_id" => 43
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, group: %Group{id: id}} do
      conn = put(conn, ~p"/api/group/#{id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete group" do
    setup [:create_group]

    test "deletes chosen group", %{conn: conn, group: %Group{id: id}} do
      conn = delete(conn, ~p"/api/group/#{id}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/group/#{id}")
      end
    end
  end

  defp create_group(_) do
    group = group_fixture()
    %{group: group}
  end
end
