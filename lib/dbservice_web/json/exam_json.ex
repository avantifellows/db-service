defmodule DbserviceWeb.ExamJSON do
  def index(%{exam: exam}) do
    for(e <- exam, do: render(e))
  end

  def show(%{exam: exam}) do
    render(exam)
  end

  def render(exam) do
    %{
      id: exam.id,
      name: exam.name,
      exam_id: exam.exam_id,
      cutoff_id: exam.cutoff_id,
      conducting_body: exam.conducting_body,
      registration_deadline: exam.registration_deadline,
      date: exam.date,
      cutoff: exam.cutoff
    }
  end
end
