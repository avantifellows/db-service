defmodule DbserviceWeb.StudentExamRecordJSON do
  def index(%{student_exam_record: student_exam_record}) do
    %{data: for(ser <- student_exam_record, do: data(ser))}
  end

  def show(%{student_exam_record: student_exam_record}) do
    %{data: data(student_exam_record)}
  end

  def data(student_exam_record) do
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
