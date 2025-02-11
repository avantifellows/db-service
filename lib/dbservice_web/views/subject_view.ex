defmodule DbserviceWeb.SubjectView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SubjectView
  alias Dbservice.Utils.Util

  def render("index.json", %{subject: subject}) do
    render_many(subject, SubjectView, "subject.json")
  end

  def render("show.json", %{subject: subject}) do
    render_one(subject, SubjectView, "subject.json")
  end

  def render("subject.json", %{subject: subject}) do
    default_name = Util.get_default_name(subject.name, :subject)

    %{
      id: subject.id,
      # For backward compatibility
      name: default_name,
      # New field with full name data
      names: subject.name,
      code: subject.code,
      parent_id: subject.parent_id
    }
  end
end
