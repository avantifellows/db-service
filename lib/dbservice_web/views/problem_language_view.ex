defmodule DbserviceWeb.ProblemLanguageView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ProblemLanguageView

  def render("index.json", %{problem_language: problem_language}) do
    render_many(problem_language, ProblemLanguageView, "problem_language.json")
  end

  def render("show.json", %{problem_language: problem_language}) do
    render_one(problem_language, ProblemLanguageView, "problem_language.json")
  end

  def render("problem_language.json", %{problem_language: problem_language}) do
    %{
      id: problem_language.id,
      res_id: problem_language.res_id,
      lang_id: problem_language.lang_id,
      meta_data: problem_language.meta_data
    }
  end
end
