defmodule Dbservice.Resources.Resource do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Curriculums.Curriculum
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic
  alias Dbservice.Sources.Source
  alias Dbservice.Purposes.Purpose
  alias Dbservice.Concepts.Concept
  alias Dbservice.LearningObjectives.LearningObjective
  alias Dbservice.Tags.Tag

  schema "resource" do
    field(:name, :string)
    field(:type, :string)
    field(:type_params, :map)
    field(:difficulty_level, :string)

    timestamps()

    belongs_to(:curriculum, Curriculum)
    belongs_to(:chapter, Chapter)
    belongs_to(:topic, Topic)
    belongs_to(:source, Source)
    belongs_to(:purpose, Purpose)
    belongs_to(:concept, Concept)
    belongs_to(:learning_objective, LearningObjective)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(purpose, attrs) do
    purpose
    |> cast(attrs, [
      :name,
      :type,
      :type_params,
      :difficulty_level,
      :curriculum_id,
      :chapter_id,
      :topic_id,
      :source_id,
      :purpose_id,
      :concept_id,
      :learning_objective_id,
      :tag_id
    ])
  end
end
