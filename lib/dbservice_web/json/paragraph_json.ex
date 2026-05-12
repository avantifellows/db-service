defmodule DbserviceWeb.ParagraphJSON do
  alias DbserviceWeb.ProblemLanguageJSON

  def index(%{paragraph: paragraph}) do
    for(p <- paragraph, do: render(p))
  end

  def show(%{paragraph: paragraph, problem_lang: problem_lang}) do
    render(paragraph, problem_lang)
  end

  def render(%Dbservice.Resources.Paragraph{} = paragraph, problem_lang \\ nil) do
    base =
      %{
        id: paragraph.id,
        body: paragraph.body
      }

    if is_list(problem_lang) do
      Map.put(base, :problem_lang, Enum.map(problem_lang, &ProblemLanguageJSON.render/1))
    else
      base
    end
  end
end
