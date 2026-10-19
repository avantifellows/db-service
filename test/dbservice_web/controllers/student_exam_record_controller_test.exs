defmodule DbserviceWeb.StudentExamRecordControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  setup %{conn: conn} do
    {_user, student} = student_fixture()
    {:ok, exam} = Dbservice.Exams.create_exam(%{name: "JEE Main #{System.unique_integer()}"})

    {:ok, conn: put_req_header(conn, "accept", "application/json"), student: student, exam: exam}
  end

  describe "create" do
    test "stores the sittings applied for", %{conn: conn, student: student, exam: exam} do
      conn =
        post(conn, ~p"/api/student-exam-record", %{
          student_id: student.id,
          exam_id: exam.id,
          application_number: "APP-#{System.unique_integer([:positive])}",
          sessions_applied: [2, 1]
        })

      assert %{"sessions_applied" => [1, 2]} = json_response(conn, 201)
    end

    test "answers 422 when the application number is missing", %{
      conn: conn,
      student: student,
      exam: exam
    } do
      # The create doubles as an upsert keyed on the application number, so a
      # missing one used to raise out of the lookup instead of being validated.
      conn =
        post(conn, ~p"/api/student-exam-record", %{
          student_id: student.id,
          exam_id: exam.id,
          application_password: "pw"
        })

      assert %{"errors" => %{"application_number" => _}} = json_response(conn, 422)
    end

    test "updates the existing record for a repeated application number", %{
      conn: conn,
      student: student,
      exam: exam
    } do
      number = "APP-#{System.unique_integer([:positive])}"
      attrs = %{student_id: student.id, exam_id: exam.id, application_number: number}

      created = json_response(post(conn, ~p"/api/student-exam-record", attrs), 201)

      updated =
        json_response(
          post(conn, ~p"/api/student-exam-record", Map.put(attrs, :sessions_applied, [1])),
          200
        )

      assert created["id"] == updated["id"]
      assert updated["sessions_applied"] == [1]
    end
  end
end
