defmodule DbserviceWeb.SchoolControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SchoolsFixtures

  alias Dbservice.Schools.School

  @create_attrs %{
    code: "some code",
    medium: "some medium",
    name: "some name"
  }
  @update_attrs %{
    code: "some updated code",
    medium: "some updated medium",
    name: "some updated name"
  }
  @invalid_attrs %{code: nil, medium: nil, name: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all school", %{conn: conn} do
      conn = get(conn, Routes.school_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create school" do
    test "renders school when data is valid", %{conn: conn} do
      conn = post(conn, Routes.school_path(conn, :create), school: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.school_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "code" => "some code",
               "medium" => "some medium",
               "name" => "some name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.school_path(conn, :create), school: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update school" do
    setup [:create_school]

    test "renders school when data is valid", %{conn: conn, school: %School{id: id} = school} do
      conn = put(conn, Routes.school_path(conn, :update, school), school: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.school_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "code" => "some updated code",
               "medium" => "some updated medium",
               "name" => "some updated name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, school: school} do
      conn = put(conn, Routes.school_path(conn, :update, school), school: @invalid_attrs)
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
