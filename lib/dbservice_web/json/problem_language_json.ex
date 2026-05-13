defmodule DbserviceWeb.ProblemLanguageJSON do
  alias Dbservice.Paragraphs
  alias Dbservice.Resources.Paragraph
  alias Dbservice.Resources.Resource

  def index(%{problem_language: problem_language}) do
    for(pl <- problem_language, do: render(pl))
  end

  def show(%{problem_language: problem_language}) do
    render(problem_language)
  end

  def render(problem_language) do
    base = %{
      id: problem_language.id,
      res_id: problem_language.res_id,
      lang_id: problem_language.lang_id,
      paragraph_id: problem_language.paragraph_id,
      meta_data: problem_language.meta_data
    }

    maybe_put_paragraph(
      base,
      Map.get(problem_language, :resource),
      Map.get(problem_language, :paragraph)
    )
  end

  defp maybe_put_paragraph(map, %Resource{} = resource, %Paragraph{} = paragraph) do
    if Paragraphs.comprehension_problem?(resource, %{}) do
      Map.put(map, :paragraph, %{id: paragraph.id, body: paragraph.body})
    else
      map
    end
  end

  defp maybe_put_paragraph(map, _resource, _paragraph), do: map
end
