defmodule Dbservice.Curriculums.Curriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  # alias Dbservice.Tags.Tag
  alias Dbservice.Resources.Resource
  alias Dbservice.Chapters.Chapter

  schema "curriculum" do
    field(:name, :string)
    field(:code, :string)

    timestamps()

    has_many(:resource, Resource)
    has_many(:chapter, Chapter)
    # belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(curriculum, attrs) do
    curriculum
    |> cast(attrs, [
      :name,
      :code,
      # :tag_id
    ])
  end
end
