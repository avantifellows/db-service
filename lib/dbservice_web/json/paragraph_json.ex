defmodule DbserviceWeb.ParagraphJSON do
  alias DbserviceWeb.ProblemLanguageJSON

  def index(%{paragraph: paragraph}) do
    for(p <- paragraph, do: render(p))
  end

  def show(%{paragraph: paragraph, problem_langs: problem_langs}) do
    render(paragraph, problem_langs)
  end

  def render(%Dbservice.Resources.Paragraph{} = paragraph, problem_langs \\ nil) do
    base =
      %{
        id: paragraph.id,
        body: paragraph.body,
        lang_id: paragraph.lang_id
      }

    if is_list(problem_langs) do
      Map.put(base, :problem_langs, Enum.map(problem_langs, &ProblemLanguageJSON.render/1))
    else
      base
    end
  end
end
