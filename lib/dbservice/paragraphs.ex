defmodule Dbservice.Paragraphs do
  @moduledoc """
  Paragraphs store instructional text (`body`); linked problems use
  `problem_lang` rows with `paragraph_id` (language per problem is `problem_lang.lang_id`).
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Resources.Paragraph

  def list_paragraph do
    Repo.all(from(p in Paragraph, order_by: [asc: p.id]))
  end

  def fetch_paragraph!(id), do: Repo.get!(Paragraph, id)

  def get_paragraph!(id), do: Repo.get!(Paragraph, id)

  def get_paragraph_with_problem_langs!(id) do
    paragraph = Repo.get!(Paragraph, id)
    problem_langs = list_problem_langs_for_paragraph(id)
    %{paragraph: paragraph, problem_langs: problem_langs}
  end

  def list_problem_langs_for_paragraph(paragraph_id) do
    from(pl in ProblemLanguage,
      join: r in Resource,
      on: r.id == pl.res_id,
      where: r.type == "problem" and pl.paragraph_id == ^paragraph_id,
      order_by: [asc: pl.id]
    )
    |> Repo.all()
  end

  def create_paragraph(attrs \\ %{}) do
    %Paragraph{}
    |> Paragraph.changeset(attrs)
    |> Repo.insert()
  end

  def update_paragraph(%Paragraph{} = paragraph, attrs) do
    paragraph
    |> Paragraph.changeset(attrs)
    |> Repo.update()
  end

  def delete_paragraph(%Paragraph{} = paragraph) do
    Repo.delete(paragraph)
  end

  def change_paragraph(%Paragraph{} = paragraph, attrs \\ %{}) do
    Paragraph.changeset(paragraph, attrs)
  end
end
