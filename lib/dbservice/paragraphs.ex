defmodule Dbservice.Paragraphs do
  @moduledoc """
  Paragraphs bundle multilingual instructional text with linked `problem_lang` rows.
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
    problem_langs = list_problem_langs_for_paragraph(id, paragraph.lang_id)
    %{paragraph: paragraph, problem_langs: problem_langs}
  end

  def list_problem_langs_for_paragraph(paragraph_id, lang_id \\ nil) do
    # We store paragraph linkage in `resource.type_params` since it is not language-dependent.
    #
    # Expected shape for problem resources:
    # type_params: %{ "paragraph_id" => <paragraph_id> }
    from(pl in ProblemLanguage,
      join: r in Resource,
      on: r.id == pl.res_id,
      where:
        r.type == "problem" and
          fragment("?->>'paragraph_id' = ?", r.type_params, ^to_string(paragraph_id)),
      where: is_nil(^lang_id) or pl.lang_id == ^lang_id,
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
