defmodule DbserviceWeb.SchoolControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SchoolsFixtures

  alias Dbservice.Schools.School

  @create_attrs %{
    code: "some code",
    name: "some name",
    udise_code: "some udise code",
    type: "some type",
    category: "some category",
    region: "some region",
    state_code: "some state code",
    state: "some state",
    district_code: "some district code",
    district: "some district",
    block_code: "some block code",
    block_name: "some block name",
    board: "some board",
    board_medium: "some board medium"
  }
  @update_attrs %{
    code: "some updated code",
    name: "some updated name",
    udise_code: "some updated udise code",
    type: "some updated type",
    category: "some updated category",
    region: "some updated region",
    state_code: "some updated state code",
    state: "some updated state",
    district_code: "some updated district code",
    district: "some updated district",
    block_code: "some updated block code",
    block_name: "some updated block name",
    board: "some updated board",
    board_medium: "some updated board medium"
  }
  @invalid_attrs %{
    code: nil,
    name: nil,
    udise_code: nil,
    type: nil,
    category: nil,
    region: nil,
    state_code: nil,
    state: nil,
    district_code: nil,
    district: nil,
    block_code: nil,
    block_name: nil,
    board: nil,
    board_medium: nil
  }
  @valid_fields [
    "block_code",
    "block_name",
    "board",
    "board_medium",
    "category",
    "code",
    "district",
    "district_code",
    "id",
    "name",
    "region",
    "state",
    "state_code",
    "type",
    "udise_code"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all school", %{conn: conn} do
      conn = get(conn, Routes.school_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create school" do
    test "renders school when data is valid", %{conn: conn} do
      conn = post(conn, Routes.school_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.school_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "code" => "some code",
               "name" => "some name",
               "board_medium" => "some board medium"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.school_path(conn, :create), school: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update school" do
    setup [:create_school]

    test "renders school when data is valid", %{conn: conn, school: %School{id: id} = school} do
      conn = put(conn, Routes.school_path(conn, :update, school), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.school_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "code" => "some updated code",
               "name" => "some updated name",
               "board_medium" => "some updated board medium"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, school: school} do
      conn = put(conn, Routes.school_path(conn, :update, school), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete school" do
    setup [:create_school]

    test "deletes chosen school", %{conn: conn, school: school} do
      conn = delete(conn, Routes.school_path(conn, :delete, school))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.school_path(conn, :show, school))
      end
    end
  end

  defp create_school(_) do
    school = school_fixture()
    %{school: school}
  end
end
