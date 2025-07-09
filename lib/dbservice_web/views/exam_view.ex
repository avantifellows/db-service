defmodule DbserviceWeb.ExamView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ExamView

  def render("index.json", %{exam: exam}) do
    render_many(exam, ExamView, "exam.json")
  end

  def render("show.json", %{exam: exam}) do
    render_one(exam, ExamView, "exam.json")
  end

  def render("exam.json", %{exam: exam}) do
    %{
      id: exam.id,
      exam_id: exam.exam_id,
      name: exam.name,
      cutoff_id: exam.cutoff_id,
      conducting_body: exam.conducting_body,
      registration_deadline: exam.registration_deadline,
      date: exam.date,
      cutoff: exam.cutoff
    }
  end
end
