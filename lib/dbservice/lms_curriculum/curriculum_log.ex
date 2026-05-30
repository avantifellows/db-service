defmodule Dbservice.LmsCurriculum.CurriculumLog do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.ChapterExamConfig
  alias Dbservice.LmsCurriculum.CurriculumLogTopic

  schema "lms_curriculum_logs" do
    field :school_code, :string
    field :exam_track, :string
    field :log_date, :date
    field :duration_minutes, :integer
    field :created_by_email, :string
    field :inserted_by_email, :string
    field :updated_by_email, :string
    field :deleted_at, :naive_datetime

    belongs_to :program, Dbservice.Programs.Program
    belongs_to :grade, Dbservice.Grades.Grade
    belongs_to :subject, Dbservice.Subjects.Subject

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
      :log_date,
      :duration_minutes,
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
      :log_date,
      :duration_minutes
    ])
    |> validate_length(:school_code, min: 1, max: 255)
    |> validate_inclusion(:exam_track, ChapterExamConfig.exam_tracks())
    |> validate_number(:duration_minutes, greater_than: 0, less_than_or_equal_to: 720)
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:grade_id)
    |> foreign_key_constraint(:subject_id)
    |> check_constraint(:exam_track, name: :lms_curriculum_logs_exam_track_check)
    |> check_constraint(:duration_minutes, name: :lms_curriculum_logs_duration_minutes_check)
  end
end
