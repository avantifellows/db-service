defmodule DbserviceWeb.ExamView do
  use DbserviceWeb, :view

  def render("index.json", %{exam: exam}) do
    Enum.map(exam, &exam_json/1)
  end

  def render("show.json", %{exam: exam}) do
    exam_json(exam)
  end

  def exam_json(%{id: id, name: name, registration_deadline: registration_deadline, date: date, cutoff: cutoff}) do
    %{
      id: id,
      name: name,
      registration_deadline: registration_deadline,
      date: date,
      cutoff: cutoff
    }
  end
end
