defmodule DbserviceWeb.TeacherControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  @create_attrs %{
    designation: "some designation",
    teacher_id: "some teacher id",
    is_af_teacher: false
  }
  @update_attrs %{
    designation: "some updated designation",
    teacher_id: "some updated teacher id",
    is_af_teacher: true
  }
  @invalid_attrs %{
    designation: nil,
    teacher_id: nil,
    is_af_teacher: nil,
    user_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all teacher", %{conn: conn} do
      {_user, teacher} = teacher_fixture()
      conn = get(conn, ~p"/api/teacher")
      resp = json_response(conn, 200)
      assert is_list(resp)
      assert Enum.any?(resp, fn t -> t["id"] == teacher.id end)
      found_teacher = Enum.find(resp, fn t -> t["id"] == teacher.id end)
      assert found_teacher["teacher_id"] == teacher.teacher_id
    end
  end

  describe "create teacher" do
    test "renders teacher when data is valid", %{conn: conn} do
      user = user_fixture()
      attrs = Map.put(@create_attrs, :user_id, user.id)

      conn = post(conn, ~p"/api/teacher", attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/teacher/#{id}")

      assert %{
               "id" => ^id,
               "designation" => "some designation",
               "teacher_id" => "some teacher id"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/teacher", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show teacher" do
    setup [:create_teacher]

    test "shows chosen teacher", %{conn: conn, teacher: teacher} do
      conn = get(conn, ~p"/api/teacher/#{teacher.id}")
      assert json_response(conn, 200)["id"] == teacher.id
    end
  end

  describe "update teacher" do
    setup [:create_teacher]

    test "renders teacher when data is valid", %{conn: conn, teacher: teacher} do
      user = user_fixture()
      attrs = Map.put(@update_attrs, :user_id, user.id)

      conn = put(conn, ~p"/api/teacher/#{teacher.id}", attrs)
      %{"id" => id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/teacher/#{id}")

      assert %{
               "id" => ^id,
               "designation" => "some updated designation",
               "teacher_id" => "some updated teacher id"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, teacher: teacher} do
      conn = put(conn, ~p"/api/teacher/#{teacher.id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete teacher" do
    setup [:create_teacher]

    test "deletes chosen teacher", %{conn: conn, teacher: teacher} do
      conn = delete(conn, ~p"/api/teacher/#{teacher.id}")
      assert response(conn, 204)

      # Verify teacher is actually deleted
      conn = get(conn, ~p"/api/teacher/#{teacher.id}")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_teacher(_) do
    {_user, teacher} = teacher_fixture()
    %{teacher: teacher}
  end
end
