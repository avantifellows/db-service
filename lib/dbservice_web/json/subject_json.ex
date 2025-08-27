defmodule DbserviceWeb.SubjectJSON do
  def index(%{subject: subject}) do
    for(s <- subject, do: render(s))
  end

  def show(%{subject: subject}) do
    render(subject)
  end

  defp render(subject) do
    %{
      id: subject.id,
      name: subject.name,
      code: subject.code,
      parent_id: subject.parent_id
    }
  end
end
