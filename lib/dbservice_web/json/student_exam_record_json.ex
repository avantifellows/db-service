defmodule DbserviceWeb.StudentExamRecordJSON do
  def index(%{student_exam_record: student_exam_record}) do
    for(ser <- student_exam_record, do: render(ser))
  end

  def show(%{student_exam_record: student_exam_record}) do
    render(student_exam_record)
  end

  def render(student_exam_record) do
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
      category_rank: student_exam_record.category_rank,
      exam_email: student_exam_record.exam_email,
      exam_phone: student_exam_record.exam_phone,
      exam_roll_no: student_exam_record.exam_roll_no,
      exam_year: student_exam_record.exam_year
    }
  end
end
