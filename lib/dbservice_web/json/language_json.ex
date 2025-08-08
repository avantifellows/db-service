defmodule DbserviceWeb.LanguageJSON do
  def index(%{language: language}) do
    for(l <- language, do: render(l))
  end

  def show(%{language: language}) do
    render(language)
  end

  defp render(language) do
    %{
      id: language.id,
      name: language.name
    }
  end
end
