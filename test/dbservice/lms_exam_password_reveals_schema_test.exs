defmodule Dbservice.LmsExamPasswordRevealsSchemaTest do
  use Dbservice.DataCase, async: false

  import Dbservice.UsersFixtures

  alias Dbservice.StudentExamRecords

  @table "lms_exam_password_reveals"

  setup do
    {_user, student} = student_fixture()
    {:ok, exam} = Dbservice.Exams.create_exam(%{name: "JEE Main #{System.unique_integer()}"})

    {:ok, record} =
      StudentExamRecords.create_student_exam_record(%{
        student_id: student.id,
        exam_id: exam.id,
        application_number: "APP#{System.unique_integer([:positive])}"
      })

    %{record: record}
  end

  test "records a reveal and stamps when it happened", %{record: record} do
    assert {:ok, %{rows: [[id]]}} = insert_reveal(record, "teacher@example.org", "teacher")

    assert Repo.query!(
             "SELECT viewer_email, viewer_role, inserted_at IS NOT NULL FROM #{@table} WHERE id = $1",
             [id]
           ).rows == [["teacher@example.org", "teacher", true]]
  end

  test "rejects a blank or mixed-case viewer, and a blank role", %{record: record} do
    for {email, role} <- [{"  ", "teacher"}, {"Teacher@Example.org", "teacher"}, {"t@e.org", " "}] do
      assert_check_violation(fn -> insert_reveal(record, email, role) end)
    end
  end

  test "is append-only", %{record: record} do
    assert {:ok, %{rows: [[id]]}} = insert_reveal(record, "pm@example.org", "program_manager")

    assert_check_violation(fn ->
      Repo.query("UPDATE #{@table} SET viewer_role = 'admin' WHERE id = $1", [id])
    end)

    assert_check_violation(fn -> Repo.query("DELETE FROM #{@table} WHERE id = $1", [id]) end)
  end

  test "outlives the exam registration it revealed", %{record: record} do
    assert {:ok, _} = insert_reveal(record, "pm@example.org", "program_manager")
    assert {:ok, _} = StudentExamRecords.delete_student_exam_record(record)

    assert Repo.query!(
             "SELECT student_exam_record_id FROM #{@table}",
             []
           ).rows == [[record.id]]
  end

  defp insert_reveal(record, email, role) do
    Repo.query(
      """
      INSERT INTO #{@table} (student_id, student_exam_record_id, exam_id, viewer_email, viewer_role)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
      """,
      [record.student_id, record.id, record.exam_id, email, role]
    )
  end

  defp assert_check_violation(query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :check_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
