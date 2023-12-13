defmodule DbserviceWeb.StudentExamRecordView do
  use DbserviceWeb, :view
  alias DbserviceWeb.StudentExamRecordView

  def render("index.json", %{student_exam_record: student_exam_record}) do
    render_many(student_exam_record, StudentExamRecordView, "student_exam_record.json")
  end

  def render("show.json", %{student_exam_record: student_exam_record}) do
    render_one(student_exam_record, StudentExamRecordView, "student_exam_record.json")
  end

  def render("student_exam_record.json", %{student_exam_record: student_exam_record}) do
    %{
      id: student_exam_record.id,
      student_id: student_exam_record.student_id,
      exam_id: student_exam_record.exam_id,
      application_number: student_exam_record.application_number,
      application_password: student_exam_record.application_password,
      date: student_exam_record.date,
      score: student_exam_record.score,
      rank: student_exam_record.rank
    }
  end
end
