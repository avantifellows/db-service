defmodule DbserviceWeb.SubjectView do
  use DbserviceWeb, :view

  def render("index.json", %{subject: subject}) do
    Enum.map(subject, &subject_json/1)
  end

  def render("show.json", %{subject: subject}) do
    subject_json(subject)
  end

  def subject_json(subject) do
    %{
      id: subject.id,
      name: subject.name,
      code: subject.code,
      tag_id: subject.tag_id
    }
  end
end
