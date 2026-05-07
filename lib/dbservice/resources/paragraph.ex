defmodule Dbservice.Resources.Paragraph do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.ProblemLanguage

  schema "paragraph" do
    field(:body, :string)

    timestamps()

    has_many(:problem_lang, ProblemLanguage, foreign_key: :paragraph_id)
  end

  @doc false
  def changeset(paragraph, attrs) do
    paragraph
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
