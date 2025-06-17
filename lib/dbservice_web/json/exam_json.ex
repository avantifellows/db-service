defmodule DbserviceWeb.ExamJSON do
  def index(%{exam: exam}) do
    for(e <- exam, do: data(e))
  end

  def show(%{exam: exam}) do
    data(exam)
  end

  defp data(exam) do
    %{
      id: exam.id,
      name: exam.name,
      registration_deadline: exam.registration_deadline,
      date: exam.date,
      cutoff: exam.cutoff
    }
  end
end
