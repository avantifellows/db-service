defmodule Dbservice.Tags.Tag do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Curriculums.Curriculum
  alias Dbservice.Grades.Grade
  alias Dbservice.Subjects.Subject
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic
  alias Dbservice.Concepts.Concept
  alias Dbservice.LearningObjectives.LearningObjective
  alias Dbservice.Purposes.Purpose
  alias Dbservice.Sources.Source

  schema "tag" do
    field(:name, :string)
    field(:description, :string)

    timestamps()

    has_one(:curriculum, Curriculum)
    has_one(:grade, Grade)
    has_one(:subject, Subject)
    has_one(:chapter, Chapter)
    has_one(:topic, Topic)
    has_one(:concept, Concept)
    has_one(:learning_objective, LearningObjective)
    has_one(:purpose, Purpose)
    has_one(:source, Source)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [
      :name,
      :description
    ])
  end
end
