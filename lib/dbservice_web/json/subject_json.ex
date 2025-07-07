defmodule DbserviceWeb.SubjectJSON do
  def index(%{subject: subject}) do
    for(s <- subject, do: render(s))
  end

  def show(%{subject: subject}) do
    render(subject)
  end

  def render(subject) do
    %{
      id: subject.id,
      name: subject.name,
      code: subject.code,
      tag_id: subject.tag_id
    }
  end
end
