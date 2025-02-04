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
    default_name = get_default_name(subject.name)

    %{
      id: subject.id,
      # For backward compatibility
      name: default_name,
      # New field with full name data
      names: subject.name,
      code: subject.code,
      parent_id: subject.parent_id
      # tag_id: subject.tag_id
    }
  end

  defp get_default_name(names) when is_list(names) do
    case get_english_language_id() do
      nil ->
        # Fallback to first name if English language ID not found
        case List.first(names) do
          %{"subject" => value} -> value
          _ -> nil
        end

      english_id ->
        # Try to find English translation
        case Enum.find(names, &(&1["lang_id"] == english_id)) do
          %{"subject" => value} ->
            value

          nil ->
            # Fallback to first name if English translation not found
            case List.first(names) do
              %{"subject" => value} -> value
              _ -> nil
            end
        end
    end
  end

  defp get_default_name(_), do: nil

  defp get_english_language_id do
    alias Dbservice.Repo
    alias Dbservice.Languages.Language

    case Repo.get_by(Language, name: "English") do
      %Language{id: id} -> id
      nil -> nil
    end
  end
end
