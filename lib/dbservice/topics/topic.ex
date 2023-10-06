defmodule Dbservice.Topics.Topic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Grades.Grade
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Tags.Tag
  alias Dbservice.Concepts.Concept
  alias Dbservice.Resources.Resource

  schema "topic" do
    field(:name, :string)
    field(:code, :string)

    timestamps()

    has_many(:concept, Concept)
    has_many(:resource, Resource)
    belongs_to(:grade, Grade)
    belongs_to(:chapter, Chapter)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [
      :name,
      :code,
      :grade_id,
      :chapter_id,
      :tag_id
    ])
  end
end
