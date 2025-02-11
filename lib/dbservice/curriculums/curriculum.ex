defmodule Dbservice.Curriculums.Curriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Chapters.Chapter

  schema "curriculum" do
    field(:name, :string)
    field(:code, :string)

    timestamps()

    has_many(:chapter, Chapter)
  end

  @doc false
  def changeset(curriculum, attrs) do
    curriculum
    |> cast(attrs, [
      :name,
      :code
    ])
  end
end
