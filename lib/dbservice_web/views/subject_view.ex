defmodule DbserviceWeb.SubjectView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SubjectView

  def render("index.json", %{subject: subject}) do
    render_many(subject, SubjectView, "subject.json")
  end

  def render("show.json", %{subject: subject}) do
    render_one(subject, SubjectView, "subject.json")
  end

  def render("subject.json", %{subject: subject}) do
    %{
      id: subject.id,
      name: subject.name,
      code: subject.code,
      parent_id: subject.parent_id
    }
  end
end
