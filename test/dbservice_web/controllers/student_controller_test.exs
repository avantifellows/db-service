defmodule DbserviceWeb.StudentControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.Users.Student

  @create_attrs %{
    category: "some category",
    father_name: "some father_name",
    father_phone: "some father_phone",
    mother_name: "some mother_name",
    mother_phone: "some mother_phone",
    stream: "some stream",
    uuid: "some uuid"
  }
  @update_attrs %{
    category: "some updated category",
    father_name: "some updated father_name",
    father_phone: "some updated father_phone",
    mother_name: "some updated mother_name",
    mother_phone: "some updated mother_phone",
    stream: "some updated stream",
    uuid: "some updated uuid"
  }
  @invalid_attrs %{
    category: nil,
    father_name: nil,
    father_phone: nil,
    mother_name: nil,
    mother_phone: nil,
    stream: nil,
    uuid: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all student", %{conn: conn} do
      conn = get(conn, Routes.student_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create student" do
    test "renders student when data is valid", %{conn: conn} do
      conn = post(conn, Routes.student_path(conn, :create), student: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.student_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "category" => "some category",
               "father_name" => "some father_name",
               "father_phone" => "some father_phone",
               "mother_name" => "some mother_name",
               "mother_phone" => "some mother_phone",
               "stream" => "some stream",
               "uuid" => "some uuid"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.student_path(conn, :create), student: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update student" do
    setup [:create_student]

    test "renders student when data is valid", %{conn: conn, student: %Student{id: id} = student} do
      conn = put(conn, Routes.student_path(conn, :update, student), student: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.student_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "category" => "some updated category",
               "father_name" => "some updated father_name",
               "father_phone" => "some updated father_phone",
               "mother_name" => "some updated mother_name",
               "mother_phone" => "some updated mother_phone",
               "stream" => "some updated stream",
               "uuid" => "some updated uuid"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, student: student} do
      conn = put(conn, Routes.student_path(conn, :update, student), student: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete student" do
    setup [:create_student]

    test "deletes chosen student", %{conn: conn, student: student} do
      conn = delete(conn, Routes.student_path(conn, :delete, student))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.student_path(conn, :show, student))
      end
    end
  end

  defp create_student(_) do
    student = student_fixture()
    %{student: student}
  end
end
