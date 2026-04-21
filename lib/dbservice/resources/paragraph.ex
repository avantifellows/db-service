defmodule Dbservice.Resources.Paragraph do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Languages.Language

  schema "paragraph" do
    field(:body, {:array, :map})
    belongs_to(:language, Language, foreign_key: :lang_id)

    timestamps()
  end

  @doc false
  def changeset(paragraph, attrs) do
    paragraph
    |> cast(attrs, [:body, :lang_id])
    |> validate_required([:body, :lang_id])
  end
end
