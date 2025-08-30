defmodule DbserviceWeb.ExamJSON do
  def index(%{exam: exam}) do
    for(e <- exam, do: render(e))
  end

  def show(%{exam: exam}) do
    render(exam)
  end

  def render(exam) do
    base_exam = %{
      id: exam.id,
      exam_name: exam.exam_name,
      counselling_body: exam.counselling_body,
      type: exam.type
    }

    # Include exam_occurrences if they are loaded
    case Map.get(exam, :exam_occurrences) do
      %Ecto.Association.NotLoaded{} -> base_exam
      nil -> base_exam
      exam_occurrences ->
        Map.put(base_exam, :exam_occurrences,
          Enum.map(exam_occurrences, &DbserviceWeb.ExamOccurrenceJSON.render/1))
    end
  end
end
