defmodule Dbservice.Resources.ProblemLanguage do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Paragraph
  alias Dbservice.Resources.Resource
  alias Dbservice.Languages.Language

  schema "problem_lang" do
    field(:meta_data, :map)
    belongs_to(:paragraph, Paragraph)
    belongs_to :resource, Resource, foreign_key: :res_id
    belongs_to :language, Language, foreign_key: :lang_id

    timestamps()
  end

  @doc false
  def changeset(problem_lang, attrs) do
    problem_lang
    |> cast(attrs, [
      :res_id,
      :lang_id,
      :meta_data,
      :paragraph_id
    ])
    |> validate_required([
      :res_id,
      :lang_id
    ])
  end
end
