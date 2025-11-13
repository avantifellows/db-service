defmodule DbserviceWeb.ExamOccurrenceJSON do
  def index(%{exam_occurrence: exam_occurrences}) do
    for(eo <- exam_occurrences, do: render(eo))
  end

  def show(%{exam_occurrence: exam_occurrence}) do
    render(exam_occurrence)
  end

  def render(exam_occurrence) do
    %{
      id: exam_occurrence.id,
      exam_id: exam_occurrence.exam_id,
      year: exam_occurrence.year,
      exam_session: exam_occurrence.exam_session,
      registration_end_date: exam_occurrence.registration_end_date,
      session_date: exam_occurrence.session_date
    }
  end
end
