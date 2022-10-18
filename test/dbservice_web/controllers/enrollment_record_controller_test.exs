defmodule DbserviceWeb.EnrollmentRecordControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SchoolsFixtures

  alias Dbservice.Schools.EnrollmentRecord

  @create_attrs %{
    academic_year: "some academic_year",
    grade: "some grade",
    is_current: true,
    board_medium: "some board medium",
    date_of_enrollment: ~U[2022-04-28 13:58:00Z]
  }
  @update_attrs %{
    academic_year: "some updated academic year",
    grade: "some updated grade",
    is_current: false,
    board_medium: "some updated board medium",
    date_of_enrollment: ~U[2022-04-28 13:58:00Z]
  }
  @invalid_attrs %{
    academic_year: nil,
    grade: nil,
    is_current: false,
    board_medium: nil,
    date_of_enrollment: nil,
    student_id: nil,
    school_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all enrollment_record", %{conn: conn} do
      enrollment_record_fixture = enrollment_record_fixture()
      conn = get(conn, Routes.enrollment_record_path(conn, :index))
      assert is_list(json_response(conn, 200)) == is_list([enrollment_record_fixture])
    end
  end

  describe "create enrollment_record" do
    test "renders enrollment_record when data is valid", %{conn: conn} do
      conn = post(conn, Routes.enrollment_record_path(conn, :create), get_ids_create_attrs())
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.enrollment_record_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "academic_year" => "some academic_year",
               "grade" => "some grade",
               "is_current" => true,
               "board_medium" => "some board medium"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.enrollment_record_path(conn, :create), enrollment_record: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update enrollment_record" do
    setup [:create_enrollment_record]

    test "renders enrollment_record when data is valid", %{
      conn: conn,
      enrollment_record: %EnrollmentRecord{id: id} = enrollment_record
    } do
      conn =
        put(
          conn,
          Routes.enrollment_record_path(conn, :update, enrollment_record),
          get_ids_update_attrs()
        )

      assert %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.enrollment_record_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "academic_year" => "some updated academic year",
               "grade" => "some updated grade",
               "is_current" => false
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      enrollment_record: enrollment_record
    } do
      conn =
        put(conn, Routes.enrollment_record_path(conn, :update, enrollment_record), @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete enrollment_record" do
    setup [:create_enrollment_record]

    test "deletes chosen enrollment_record", %{conn: conn, enrollment_record: enrollment_record} do
      conn = delete(conn, Routes.enrollment_record_path(conn, :delete, enrollment_record))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.enrollment_record_path(conn, :show, enrollment_record))
      end
    end
  end

  defp create_enrollment_record(_) do
    enrollment_record = enrollment_record_fixture()
    %{enrollment_record: enrollment_record}
  end

  defp get_ids_create_attrs do
    enrollment_record_fixture = enrollment_record_fixture()
    student_id = enrollment_record_fixture.student_id
    school_id = enrollment_record_fixture.school_id
    Map.merge(@create_attrs, %{student_id: student_id, school_id: school_id})
  end

  defp get_ids_update_attrs do
    enrollment_record_fixture = enrollment_record_fixture()
    student_id = enrollment_record_fixture.student_id
    school_id = enrollment_record_fixture.school_id
    Map.merge(@update_attrs, %{student_id: student_id, school_id: school_id})
  end
end
