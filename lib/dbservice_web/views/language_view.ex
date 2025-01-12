defmodule DbserviceWeb.LanguageView do
  use DbserviceWeb, :view
  alias DbserviceWeb.LanguageView

  def render("index.json", %{language: language}) do
    render_many(language, LanguageView, "language.json")
  end

  def render("show.json", %{language: language}) do
    render_one(language, LanguageView, "language.json")
  end

  def render("language.json", %{language: language}) do
    %{
      id: language.id,
      name: language.name
    }
  end
end
