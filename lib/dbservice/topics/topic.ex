defmodule Dbservice.Topics.Topic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util, only: [validate_unique_field: 2, validate_required_on_insert: 2]

  alias Dbservice.Chapters.Chapter
  alias Dbservice.Concepts.Concept
  alias Dbservice.Resources.Resource
  alias Dbservice.TopicCurriculums.TopicCurriculum
  alias Dbservice.CmsStatuses.CmsStatus

  schema "topic" do
    field :name, {:array, :map}
    field(:code, :string)

    timestamps()

    has_many(:concept, Concept)
    belongs_to(:chapter, Chapter)
    many_to_many(:resource, Resource, join_through: "resource_topic", on_replace: :delete)
    has_many(:topic_curriculum, TopicCurriculum)
    belongs_to(:cms_status, CmsStatus)
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [
      :name,
      :code,
      :chapter_id,
      :cms_status_id
    ])
    |> validate_required_on_insert(:code)
    |> validate_unique_field(:code)
  end
end
