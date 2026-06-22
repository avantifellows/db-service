defmodule Dbservice.Chapters.Chapter do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Grades.Grade
  alias Dbservice.Subjects.Subject
  alias Dbservice.Topics.Topic
  alias Dbservice.Resources.Resource
  alias Dbservice.ChapterCurriculums.ChapterCurriculum
  alias Dbservice.CmsStatuses.CmsStatus

  schema "chapter" do
    field :name, {:array, :map}
    field(:code, :string)

    timestamps()

    has_many(:topic, Topic)
    belongs_to(:grade, Grade)
    belongs_to(:subject, Subject)
    many_to_many(:resource, Resource, join_through: "resource_chapter", on_replace: :delete)
    has_many(:chapter_curriculum, ChapterCurriculum)
    belongs_to(:cms_status, CmsStatus)
  end

  @doc false
  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [
      :name,
      :code,
      :grade_id,
      :subject_id,
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
