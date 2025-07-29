defmodule Dbservice.Chapters.Chapter do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Subjects.Subject
  alias Dbservice.Tags.Tag
  alias Dbservice.Topics.Topic
  alias Dbservice.Resources.Resource
  alias Dbservice.Curriculums.Curriculum

  schema "chapter" do
    field(:name, :string)
    field(:code, :string)
    field(:grade_ids, {:array, :integer}, default: [])

    timestamps()

    has_many(:topic, Topic)
    has_many(:resource, Resource)
    belongs_to(:subject, Subject)
    belongs_to(:tag, Tag)
    belongs_to(:curriculum, Curriculum)
  end

  @doc false
  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [
      :name,
      :code,
      :grade_ids,
      :subject_id,
      :tag_id,
      :curriculum_id
    ])
  end
end
