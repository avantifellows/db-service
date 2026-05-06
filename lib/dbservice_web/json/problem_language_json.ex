defmodule DbserviceWeb.ProblemLanguageJSON do
  def index(%{problem_language: problem_language}) do
    for(pl <- problem_language, do: render(pl))
  end

  def show(%{problem_language: problem_language}) do
    render(problem_language)
  end

  def render(problem_language) do
    %{
      id: problem_language.id,
      res_id: problem_language.res_id,
      lang_id: problem_language.lang_id,
      paragraph_id: problem_language.paragraph_id,
      meta_data: problem_language.meta_data
    }
  end
end
