defmodule Dbservice.Resources.ResourceChapter do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Resource
  alias Dbservice.Chapters.Chapter

  schema "resource_chapter" do
    belongs_to :resource, Resource
    belongs_to :chapter, Chapter

    timestamps()
  end

  @doc false
  def changeset(resource_chapter, attrs) do
    resource_chapter
    |> cast(attrs, [
      :resource_id,
      :chapter_id
    ])
    |> validate_required([
      :resource_id,
      :chapter_id
    ])
  end
end
