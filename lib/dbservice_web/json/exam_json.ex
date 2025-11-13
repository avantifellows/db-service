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
      counselling_body: exam.counselling_body,
      type: exam.type,
      exam_occurrences: render_association(exam.exam_occurrences, &render_exam_occurrences/1)
    }
  end

  defp render_association(%Ecto.Association.NotLoaded{}, _render_fn), do: nil
  defp render_association(nil, _render_fn), do: nil
  defp render_association(association, render_fn), do: render_fn.(association)

  defp render_exam_occurrences(exam_occurrences) do
    Enum.map(exam_occurrences, &DbserviceWeb.ExamOccurrenceJSON.render/1)
  end
end
