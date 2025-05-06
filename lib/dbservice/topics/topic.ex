defmodule Dbservice.Topics.Topic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Chapters.Chapter
  alias Dbservice.Concepts.Concept
  alias Dbservice.Resources.Resource
  alias Dbservice.TopicCurriculums.TopicCurriculum

  schema "topic" do
    field :name, {:array, :map}
    field(:code, :string)

    timestamps()

    has_many(:concept, Concept)
    belongs_to(:chapter, Chapter)
    many_to_many(:resource, Resource, join_through: "resource_topic", on_replace: :delete)
    has_many(:topic_curriculum, TopicCurriculum)
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [
      :name,
      :code,
      :chapter_id
    ])
  end
end
