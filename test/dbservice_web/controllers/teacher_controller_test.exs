defmodule DbserviceWeb.TeacherControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.Users.Teacher

  @create_attrs %{
    designation: "some designation",
    grade: "some grade",
    subject: "some subject",
    uuid: "some uuid",
    user_id: 242,
    school_id: 316,
    program_manager_id: 97
  }
  @update_attrs %{
    designation: "some updated designation",
    grade: "some updated grade",
    subject: "some updated subject",
    uuid: "some updated uuid",
    user_id: 242,
    school_id: 316,
    program_manager_id: 97
  }
  @invalid_attrs %{
    designation: nil,
    grade: nil,
    subject: nil,
    uuid: nil,
    user_id: nil,
    school_id: nil,
    program_manager_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all teacher", %{conn: conn} do
      conn = get(conn, Routes.teacher_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert head["designation"] == "Teacher"
    end
  end

  describe "create teacher" do
    test "renders teacher when data is valid", %{conn: conn} do
      conn = post(conn, Routes.teacher_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.teacher_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "designation" => "some designation",
               "grade" => "some grade",
               "subject" => "some subject"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.teacher_path(conn, :create), teacher: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update teacher" do
    setup [:create_teacher]

    test "renders teacher when data is valid", %{conn: conn, teacher: %Teacher{id: id} = teacher} do
      conn = put(conn, Routes.teacher_path(conn, :update, teacher), @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.teacher_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "designation" => "some updated designation",
               "grade" => "some updated grade",
               "subject" => "some updated subject"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, teacher: teacher} do
      conn = put(conn, Routes.teacher_path(conn, :update, teacher), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete teacher" do
    setup [:create_teacher]

    test "deletes chosen teacher", %{conn: conn, teacher: teacher} do
      conn = delete(conn, Routes.teacher_path(conn, :delete, teacher))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.teacher_path(conn, :show, teacher))
      end
    end
  end

  defp create_teacher(_) do
    teacher = teacher_fixture()
    %{teacher: teacher}
  end
end
