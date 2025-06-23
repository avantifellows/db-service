defmodule DbserviceWeb.ExamJSON do
  def index(%{exam: exam}) do
    for(e <- exam, do: render(e))
  end

  def show(%{exam: exam}) do
    render(exam)
  end

  defp render(exam) do
    %{
      id: exam.id,
      name: exam.name,
      registration_deadline: exam.registration_deadline,
      date: exam.date,
      cutoff: exam.cutoff
    }
  end
end
