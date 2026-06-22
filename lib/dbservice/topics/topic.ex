defmodule Dbservice.Topics.Topic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

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
    |> validate_code_uniqueness()
  end

  # Application-level guard against duplicate `code` values. A DB-level unique index is the
  # eventual guarantee, but it can't be added while existing duplicates remain in the
  # database; until those are cleaned up, this rejects new collisions coming through the API
  # and CSV import. Only enforced when a code is actually supplied (the column is still
  # nullable for now). Not race-safe on its own - that comes with the future unique index.
  defp validate_code_uniqueness(changeset) do
    case get_change(changeset, :code) do
      nil -> changeset
      "" -> changeset
      _code -> unsafe_validate_unique(changeset, :code, Dbservice.Repo)
    end
  end
end
