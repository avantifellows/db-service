defmodule Dbservice.LmsCurriculum.CurriculumLog do
  @moduledoc """
  Teacher-entered curriculum session log.

  `school_code` is intentionally stored as plain text because the LMS uses school
  codes as its school identifier and `school.code` is not unique enough to support
  a database foreign key today.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.ChapterExamConfig
  alias Dbservice.LmsCurriculum.CurriculumLogTopic

  @log_types ~w(regular class_cancelled doubt_solving)

  schema "lms_curriculum_logs" do
    field :school_code, :string
    field :exam_track, :string
    field :log_type, :string, default: "regular"
    field :log_date, :date
    field :duration_minutes, :integer
    field :created_by_email, :string
    field :inserted_by_email, :string
    field :updated_by_email, :string
    field :deleted_at, :naive_datetime

    belongs_to :program, Dbservice.Programs.Program
    belongs_to :grade, Dbservice.Grades.Grade
    belongs_to :subject, Dbservice.Subjects.Subject
    belongs_to :chapter, Dbservice.Chapters.Chapter

    has_many :curriculum_log_topics, CurriculumLogTopic
    has_many :topics, through: [:curriculum_log_topics, :topic]

    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :school_code,
      :program_id,
      :grade_id,
      :subject_id,
      :exam_track,
      :log_type,
      :log_date,
      :duration_minutes,
      :chapter_id,
      :created_by_email,
      :inserted_by_email,
      :updated_by_email,
      :deleted_at
    ])
    |> validate_required([
      :school_code,
      :program_id,
      :grade_id,
      :subject_id,
      :exam_track,
      :log_type,
      :log_date
    ])
    |> validate_length(:school_code, min: 1, max: 255)
    |> validate_inclusion(:exam_track, ChapterExamConfig.exam_tracks())
    |> validate_inclusion(:log_type, @log_types)
    |> validate_log_shape()
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:grade_id)
    |> foreign_key_constraint(:subject_id)
    |> foreign_key_constraint(:chapter_id)
    |> check_constraint(:exam_track, name: :lms_curriculum_logs_exam_track_check)
    |> check_constraint(:log_type, name: :lms_curriculum_logs_log_type_check)
    |> check_constraint(:duration_minutes, name: :lms_curriculum_logs_duration_minutes_check)
    |> check_constraint(:chapter_id, name: :lms_curriculum_logs_chapter_id_check)
    |> unique_constraint(:school_code,
      name: :lms_curriculum_logs_active_class_cancelled_unique
    )
  end

  defp validate_log_shape(changeset) do
    case get_field(changeset, :log_type) do
      "regular" ->
        changeset
        |> validate_required([:duration_minutes])
        |> validate_absent(:chapter_id)
        |> validate_duration()

      "class_cancelled" ->
        changeset
        |> validate_required([:chapter_id])
        |> validate_absent(:duration_minutes)

      "doubt_solving" ->
        changeset
        |> validate_required([:chapter_id, :duration_minutes])
        |> validate_duration()

      _other ->
        changeset
    end
  end

  defp validate_duration(changeset) do
    validate_number(changeset, :duration_minutes, greater_than: 0, less_than_or_equal_to: 720)
  end

  defp validate_absent(changeset, field) do
    if is_nil(get_field(changeset, field)) do
      changeset
    else
      add_error(changeset, field, "must be empty for this log type")
    end
  end
end
