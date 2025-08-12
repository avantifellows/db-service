defmodule Dbservice.ChapterCurriculums.ChapterCurriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Chapters.Chapter
  alias Dbservice.Curriculums.Curriculum

  schema "chapter_curriculum" do
    belongs_to :chapter, Chapter
    belongs_to :curriculum, Curriculum
    field :priority, :integer
    field :priority_text, :string
    field :weightage, :integer

    timestamps()
  end

  def changeset(chapter_curriculum, attrs) do
    chapter_curriculum
    |> cast(attrs, [:chapter_id, :curriculum_id, :priority, :priority_text, :weightage])
    |> validate_required([:chapter_id, :curriculum_id])
  end
end
