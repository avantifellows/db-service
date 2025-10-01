defmodule DbserviceWeb.EnrollmentRecordControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.EnrollmentRecordFixtures

  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  @create_attrs %{
    start_date: ~D[2022-04-28],
    end_date: ~D[2022-04-28],
    is_current: true,
    academic_year: "some academic_year",
    group_id: 1,
    group_type: "some_group",
    user_id: 1,
    subject_id: 1
  }
  @update_attrs %{
    start_date: ~D[2022-04-29],
    end_date: ~D[2022-04-29],
    is_current: false,
    academic_year: "some updated academic_year",
    group_id: 2,
    group_type: "some updated group",
    user_id: 2,
    subject_id: 2
  }
  @invalid_attrs %{
    academic_year: nil,
    start_date: nil,
    end_date: nil,
    is_current: false,
    group_id: nil,
    group_type: nil,
    user_id: nil,
    subject_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all enrollment_record", %{conn: conn} do
      enrollment_record = enrollment_record_fixture()
      conn = get(conn, ~p"/api/enrollment-record")
      resp = json_response(conn, 200)
      assert Enum.any?(resp, fn er -> er["id"] == enrollment_record.id end)
      found_record = Enum.find(resp, fn er -> er["id"] == enrollment_record.id end)
      assert found_record["academic_year"] == enrollment_record.academic_year
      assert found_record["start_date"] == Date.to_iso8601(enrollment_record.start_date)
    end
  end

  describe "create enrollment_record" do
    test "renders enrollment_record when data is valid", %{conn: conn} do
      attrs = get_ids_create_attrs()
      user_id = attrs.user_id
      group_id = attrs.group_id
      subject_id = attrs.subject_id

      conn = post(conn, ~p"/api/enrollment-record", attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/enrollment-record/#{id}")

      assert %{
               "id" => ^id,
               "academic_year" => "some academic_year",
               "start_date" => "2022-04-28",
               "end_date" => "2022-04-28",
               "is_current" => true,
               "group_id" => ^group_id,
               "group_type" => "some_group",
               "user_id" => ^user_id,
               "subject_id" => ^subject_id
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/enrollment-record", @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update enrollment_record" do
    setup [:create_enrollment_record]

    test "renders enrollment_record when data is valid", %{
      conn: conn,
      enrollment_record: %EnrollmentRecord{id: id} = enrollment_record
    } do
      attrs = get_ids_update_attrs()
      user_id = attrs.user_id
      group_id = attrs.group_id
      subject_id = attrs.subject_id

      conn =
        put(
          conn,
          ~p"/api/enrollment-record/#{enrollment_record}",
          attrs
        )

      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/enrollment-record/#{id}")

      assert %{
               "id" => ^id,
               "academic_year" => "some updated academic_year",
               "start_date" => "2022-04-29",
               "end_date" => "2022-04-29",
               "is_current" => false,
               "group_id" => ^group_id,
               "group_type" => "some updated group",
               "user_id" => ^user_id,
               "subject_id" => ^subject_id
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      enrollment_record: enrollment_record
    } do
      conn = put(conn, ~p"/api/enrollment-record/#{enrollment_record}", @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete enrollment_record" do
    setup [:create_enrollment_record]

    test "deletes chosen enrollment_record", %{conn: conn, enrollment_record: enrollment_record} do
      conn = delete(conn, ~p"/api/enrollment-record/#{enrollment_record}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/enrollment-record/#{enrollment_record}")
      end
    end
  end

  defp create_enrollment_record(_) do
    enrollment_record = enrollment_record_fixture()
    %{enrollment_record: enrollment_record}
  end

  defp get_ids_create_attrs do
    enrollment_record_fixture = enrollment_record_fixture()
    user_id = enrollment_record_fixture.user_id
    group_id = enrollment_record_fixture.group_id
    subject_id = enrollment_record_fixture.subject_id
    Map.merge(@create_attrs, %{user_id: user_id, group_id: group_id, subject_id: subject_id})
  end

  defp get_ids_update_attrs do
    enrollment_record_fixture = enrollment_record_fixture()
    user_id = enrollment_record_fixture.user_id
    group_id = enrollment_record_fixture.group_id
    subject_id = enrollment_record_fixture.subject_id
    Map.merge(@update_attrs, %{user_id: user_id, group_id: group_id, subject_id: subject_id})
  end
end
