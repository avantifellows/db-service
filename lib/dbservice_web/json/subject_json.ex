defmodule DbserviceWeb.SubjectJSON do
  def index(%{subject: subject}) do
    %{data: for(s <- subject, do: data(s))}
  end

  def show(%{subject: subject}) do
    %{data: data(subject)}
  end

  def data(subject) do
    %{
      id: subject.id,
      name: subject.name,
      code: subject.code,
      tag_id: subject.tag_id
    }
  end
end
