defmodule Dbservice.Resources.Paragraph do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "paragraph" do
    field(:body, :string)

    timestamps()
  end

  @doc false
  def changeset(paragraph, attrs) do
    paragraph
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
