defmodule DbserviceWeb.SubjectView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SubjectView
  alias Dbservice.Repo
  alias Dbservice.Languages.Language

  def render("index.json", %{subject: subject}) do
    render_many(subject, SubjectView, "subject.json")
  end

  def render("show.json", %{subject: subject}) do
    render_one(subject, SubjectView, "subject.json")
  end

  def render("subject.json", %{subject: subject}) do
    default_name = get_default_name(subject.name)

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

  defp get_english_language_id do
    case Repo.get_by(Language, name: "English") do
      %Language{id: id} -> id
      nil -> nil
    end
  end

  defp get_default_name(names) when is_list(names) do
    english_id = get_english_language_id()

    if english_id do
      case Enum.find(names, &(&1["lang_id"] == english_id)) do
        %{"subject" => value} -> value
        _ -> get_first_name(names)
      end
    else
      get_first_name(names)
    end
  end

  defp get_default_name(_), do: nil

  defp get_first_name(names) do
    case List.first(names) do
      %{"subject" => value} -> value
      _ -> nil
    end
  end
end
