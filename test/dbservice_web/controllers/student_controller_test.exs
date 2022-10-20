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
    uuid: "some uuid",
    physically_handicapped: false,
    family_income: "some family income",
    father_profession: "some father profession",
    father_education_level: "some father education level",
    mother_profession: "some mother profession",
    mother_education_level: "some mother education level",
    has_internet_access: false,
    primary_smartphone_owner: "some primary smartphone owner",
    primary_smartphone_owner_profession: "some primary smartphone owner profession"
  }
  @update_attrs %{
    category: "some updated category",
    father_name: "some updated father name",
    father_phone: "some updated father phone",
    mother_name: "some updated mother name",
    mother_phone: "some updated mother phone",
    stream: "some updated stream",
    uuid: "some updated uuid",
    physically_handicapped: false,
    family_income: "some updated family income",
    father_profession: "some updated father profession",
    father_education_level: "some updated father education level",
    mother_profession: "some updated mother profession",
    mother_education_level: "some updated mother education level",
    has_internet_access: false,
    primary_smartphone_owner: "some updated primary smartphone owner",
    primary_smartphone_owner_profession: "some updated primary smartphone owner profession"
  }
  @invalid_attrs %{
    category: nil,
    father_name: nil,
    father_phone: nil,
    mother_name: nil,
    mother_phone: nil,
    stream: nil,
    uuid: nil,
    physically_handicapped: nil,
    family_income: nil,
    father_profession: nil,
    father_education_level: nil,
    mother_profession: nil,
    mother_education_level: nil,
    time_of_device_availability: nil,
    has_internet_access: nil,
    primary_smartphone_owner: nil,
    primary_smartphone_owner_profession: nil,
    user_id: nil,
    group_id: nil
  }
  @valid_fields [
    "category",
    "family_income",
    "father_education_level",
    "father_name",
    "father_phone",
    "father_profession",
    "group_id",
    "has_internet_access",
    "id",
    "mother_education_level",
    "mother_name",
    "mother_phone",
    "mother_profession",
    "physically_handicapped",
    "primary_smartphone_owner",
    "primary_smartphone_owner_profession",
    "stream",
    "time_of_device_availability",
    "user_id",
    "uuid"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all student", %{conn: conn} do
      conn = get(conn, Routes.student_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create student" do
    test "renders student when data is valid", %{conn: conn} do
      conn = post(conn, Routes.student_path(conn, :create), get_ids_create_attrs())
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.student_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "category" => "some category",
               "father_name" => "some father_name",
               "father_phone" => "some father_phone",
               "mother_name" => "some mother_name",
               "mother_phone" => "some mother_phone",
               "stream" => "some stream",
               "uuid" => "some uuid",
               "physically_handicapped" => false,
               "family_income" => "some family income",
               "father_profession" => "some father profession",
               "father_education_level" => "some father education level",
               "mother_profession" => "some mother profession",
               "mother_education_level" => "some mother education level",
               "has_internet_access" => false,
               "primary_smartphone_owner" => "some primary smartphone owner",
               "primary_smartphone_owner_profession" => "some primary smartphone owner profession"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.student_path(conn, :create), student: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update student" do
    setup [:create_student]

    test "renders student when data is valid", %{conn: conn, student: %Student{id: id} = student} do
      conn = put(conn, Routes.student_path(conn, :update, student), get_ids_update_attrs())
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.student_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "category" => "some updated category",
               "father_name" => "some updated father name",
               "father_phone" => "some updated father phone",
               "mother_name" => "some updated mother name",
               "mother_phone" => "some updated mother phone",
               "stream" => "some updated stream",
               "uuid" => "some updated uuid",
               "physically_handicapped" => false,
               "family_income" => "some updated family income",
               "father_profession" => "some updated father profession",
               "father_education_level" => "some updated father education level",
               "mother_profession" => "some updated mother profession",
               "mother_education_level" => "some updated mother education level",
               "has_internet_access" => false,
               "primary_smartphone_owner" => "some updated primary smartphone owner",
               "primary_smartphone_owner_profession" =>
                 "some updated primary smartphone owner profession"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, student: student} do
      conn = put(conn, Routes.student_path(conn, :update, student), @invalid_attrs)
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

  defp get_ids_create_attrs do
    student_fixture = student_fixture()
    user_id = student_fixture.user_id
    group_id = student_fixture.group_id
    Map.merge(@create_attrs, %{user_id: user_id, group_id: group_id})
  end

  defp get_ids_update_attrs do
    student_fixture = student_fixture()
    user_id = student_fixture.user_id
    group_id = student_fixture.group_id
    Map.merge(@update_attrs, %{user_id: user_id, group_id: group_id})
  end
end
