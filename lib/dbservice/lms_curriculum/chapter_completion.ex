defmodule Dbservice.LmsCurriculum.ChapterCompletion do
  @moduledoc """
  Durable chapter completion state for a school/program/chapter/exam-track scope.

  `school_code` is intentionally stored as plain text because the LMS uses school
  codes as its school identifier and `school.code` is not unique enough to support
  a database foreign key today.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.ChapterExamConfig

  schema "lms_curriculum_chapter_completions" do
    field :school_code, :string
    field :exam_track, :string
    field :completed_at, :naive_datetime
    field :completed_by_email, :string
    field :inserted_by_email, :string
    field :updated_by_email, :string
    field :deleted_at, :naive_datetime

    belongs_to :program, Dbservice.Programs.Program
    belongs_to :chapter, Dbservice.Chapters.Chapter

    timestamps()
  end

  @doc false
  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [
      :school_code,
      :program_id,
      :chapter_id,
      :exam_track,
      :completed_at,
      :completed_by_email,
      :inserted_by_email,
      :updated_by_email,
      :deleted_at
    ])
    |> default_completed_at()
    |> validate_required([:school_code, :program_id, :chapter_id, :exam_track, :completed_at])
    |> validate_length(:school_code, min: 1, max: 255)
    |> validate_inclusion(:exam_track, ChapterExamConfig.exam_tracks())
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:school_code, :program_id, :chapter_id, :exam_track],
      name: :lms_curriculum_chapter_completions_active_unique
    )
    |> check_constraint(:exam_track, name: :lms_curriculum_chapter_completions_exam_track_check)
  end

  defp default_completed_at(changeset) do
    case get_field(changeset, :completed_at) do
      nil -> put_change(changeset, :completed_at, now())
      _completed_at -> changeset
    end
  end

  defp now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end
end
