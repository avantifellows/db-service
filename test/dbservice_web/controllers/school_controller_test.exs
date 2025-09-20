defmodule DbserviceWeb.SchoolControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SchoolsFixtures

  alias Dbservice.Schools.School

  @create_attrs %{
    code: "some code",
    name: "some name",
    udise_code: "some udise code",
    gender_type: "some gender type",
    af_school_category: "some af school category",
    region: "some region",
    state_code: "some state code",
    state: "some state",
    district_code: "some district code",
    district: "some district",
    block_code: "some block code",
    block_name: "some block name",
    board: "some board",
    user_id: nil
  }
  @update_attrs %{
    code: "some updated code",
    name: "some updated name",
    udise_code: "some updated udise code",
    gender_type: "some updated gender type",
    af_school_category: "some updated af school category",
    region: "some updated region",
    state_code: "some updated state code",
    state: "some updated state",
    district_code: "some updated district code",
    district: "some updated district",
    block_code: "some updated block code",
    block_name: "some updated block name",
    board: "some updated board",
    user_id: nil
  }
  @invalid_attrs %{
    code: nil,
    name: nil,
    udise_code: nil,
    gender_type: nil,
    af_school_category: nil,
    region: nil,
    state_code: nil,
    state: nil,
    district_code: nil,
    district: nil,
    block_code: nil,
    block_name: nil,
    board: nil,
    user_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all school", %{conn: conn} do
      school = school_fixture()
      conn = get(conn, ~p"/api/school")
      [head | _tail] = json_response(conn, 200)
      assert school.id == head["id"]
      assert school.code == head["code"]
      assert school.name == head["name"]
      assert school.af_school_category == head["af_school_category"]
    end
  end

  describe "create school" do
    test "renders school when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/school", @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/school/#{id}")

      assert %{
               "id" => ^id,
               "code" => "some code",
               "name" => "some name",
               "af_school_category" => "some af school category"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/school", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update school" do
    setup [:create_school]

    test "renders school when data is valid", %{conn: conn, school: %School{id: id} = school} do
      conn = put(conn, ~p"/api/school/#{school}", @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/school/#{id}")

      assert %{
               "id" => ^id,
               "code" => "some updated code",
               "name" => "some updated name",
               "af_school_category" => "some updated af school category"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, school: school} do
      conn = put(conn, ~p"/api/school/#{school}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete school" do
    setup [:create_school]

    test "deletes chosen school", %{conn: conn, school: school} do
      conn = delete(conn, ~p"/api/school/#{school}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/school/#{school}")
      end
    end
  end

  defp create_school(_) do
    school = school_fixture()
    %{school: school}
  end
end
