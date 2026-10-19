defmodule Dbservice.StudentExamRecordsTest do
  use Dbservice.DataCase

  alias Dbservice.StudentExamRecords
  alias Dbservice.Exams.StudentExamRecord

  import Dbservice.UsersFixtures

  describe "sessions applied" do
    setup do
      {_user, student} = student_fixture()
      {:ok, exam} = Dbservice.Exams.create_exam(%{name: "JEE Main #{System.unique_integer()}"})

      %{
        attrs: %{
          student_id: student.id,
          exam_id: exam.id,
          application_number: "APP#{System.unique_integer([:positive])}"
        }
      }
    end

    test "create_student_exam_record/1 stores the sittings applied for", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: [1, 2]}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [1, 2])
               )
    end

    test "create_student_exam_record/1 stores the sittings as a sorted set", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: [1, 2]}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [2, 1, 2])
               )
    end

    test "create_student_exam_record/1 stores no sitting as nil", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: nil}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [])
               )
    end

    test "create_student_exam_record/1 rejects a session number no exam runs", %{attrs: attrs} do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [1, 7])
               )

      assert {"must be session numbers between 1 and 4", _} = changeset.errors[:sessions_applied]
    end

    test "update_student_exam_record/2 clears the sittings", %{attrs: attrs} do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(Map.put(attrs, :sessions_applied, [1]))

      assert {:ok, %StudentExamRecord{sessions_applied: nil}} =
               StudentExamRecords.update_student_exam_record(record, %{sessions_applied: []})
    end
  end
end
