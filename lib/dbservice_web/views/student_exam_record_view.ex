defmodule DbserviceWeb.StudentExamRecordView do
  use DbserviceWeb, :view
  def render("index.json", %{student_exam_record: student_exam_records}) do
    Enum.map(student_exam_records, &student_exam_record_json/1)
  end

  def render("show.json", %{student_exam_record: student_exam_record}) do
      student_exam_record_json(student_exam_record)
  end

  def student_exam_record_json(student_exam_record) do

    %{
      id: student_exam_record.id,
      student_id: student_exam_record.student_id,
      exam_id: student_exam_record.exam_id,
      application_number: student_exam_record.application_number,
      application_password: student_exam_record.application_password,
      date: student_exam_record.date,
      score: student_exam_record.score,
      percentile: student_exam_record.percentile,
      all_india_rank: student_exam_record.all_india_rank,
      category_rank: student_exam_record.category_rank
    }
  end
end
