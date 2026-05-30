defmodule Dbservice.LmsCurriculum.ChapterExamConfig do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @exam_tracks ~w(jee_main jee_advanced neet)

  schema "lms_chapter_exam_configs" do
    field :exam_track, :string
    field :is_in_syllabus, :boolean, default: true
    field :prescribed_minutes, :integer, default: 0
    field :coverage_sequence, :integer
    field :inserted_by_email, :string
    field :updated_by_email, :string

    belongs_to :chapter, Dbservice.Chapters.Chapter

    timestamps()
  end

  def exam_tracks, do: @exam_tracks

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [
      :chapter_id,
      :exam_track,
      :is_in_syllabus,
      :prescribed_minutes,
      :coverage_sequence,
      :inserted_by_email,
      :updated_by_email
    ])
    |> validate_required([
      :chapter_id,
      :exam_track,
      :is_in_syllabus,
      :prescribed_minutes,
      :coverage_sequence
    ])
    |> validate_inclusion(:exam_track, @exam_tracks)
    |> validate_number(:prescribed_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:coverage_sequence, greater_than: 0)
    |> validate_out_of_syllabus_minutes()
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:chapter_id, :exam_track],
      name: :lms_chapter_exam_configs_chapter_track_unique
    )
    |> check_constraint(:exam_track, name: :lms_chapter_exam_configs_exam_track_check)
    |> check_constraint(:prescribed_minutes,
      name: :lms_chapter_exam_configs_prescribed_minutes_check
    )
    |> check_constraint(:coverage_sequence,
      name: :lms_chapter_exam_configs_coverage_sequence_check
    )
    |> check_constraint(:prescribed_minutes,
      name: :lms_chapter_exam_configs_out_of_syllabus_minutes_check
    )
  end

  defp validate_out_of_syllabus_minutes(changeset) do
    is_in_syllabus = get_field(changeset, :is_in_syllabus)
    prescribed_minutes = get_field(changeset, :prescribed_minutes)

    if is_in_syllabus == false and prescribed_minutes != 0 do
      add_error(changeset, :prescribed_minutes, "must be 0 when the chapter is out of syllabus")
    else
      changeset
    end
  end
end
