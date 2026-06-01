defmodule Dbservice.LmsCurriculum do
  @moduledoc """
  Context for LMS curriculum tracking data.

  This context intentionally does not expose public REST endpoints. It stores the
  backend-owned curriculum log, chapter completion, and chapter exam config data
  consumed by the LMS application.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.LmsCurriculum.ChapterCompletion
  alias Dbservice.LmsCurriculum.ChapterExamConfig
  alias Dbservice.LmsCurriculum.CurriculumLog
  alias Dbservice.LmsCurriculum.CurriculumLogTopic

  def list_chapter_exam_configs(params \\ %{}) do
    ChapterExamConfig
    |> filter_chapter_exam_configs(params)
    |> order_by([c], asc: c.exam_track, asc: c.coverage_sequence, asc: c.chapter_id)
    |> Repo.all()
  end

  def get_chapter_exam_config(id), do: Repo.get(ChapterExamConfig, id)

  def create_chapter_exam_config(attrs \\ %{}) do
    %ChapterExamConfig{}
    |> ChapterExamConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_chapter_exam_config(%ChapterExamConfig{} = config, attrs) do
    config
    |> ChapterExamConfig.changeset(attrs)
    |> Repo.update()
  end

  def create_curriculum_log(attrs \\ %{}) do
    %CurriculumLog{}
    |> CurriculumLog.changeset(attrs)
    |> Repo.insert()
  end

  def get_curriculum_log(id) do
    CurriculumLog
    |> where([log], log.id == ^id and is_nil(log.deleted_at))
    |> Repo.one()
  end

  def list_curriculum_logs(params \\ %{}) do
    CurriculumLog
    |> where([log], is_nil(log.deleted_at))
    |> filter_curriculum_logs(params)
    |> order_by([log], desc: log.log_date, desc: log.inserted_at)
    |> Repo.all()
  end

  def soft_delete_curriculum_log(%CurriculumLog{} = log, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:deleted_at, now())

    log
    |> CurriculumLog.changeset(attrs)
    |> Repo.update()
  end

  def create_curriculum_log_topic(attrs \\ %{}) do
    %CurriculumLogTopic{}
    |> CurriculumLogTopic.changeset(attrs)
    |> Repo.insert()
  end

  def create_chapter_completion(attrs \\ %{}) do
    %ChapterCompletion{}
    |> ChapterCompletion.changeset(attrs)
    |> Repo.insert()
  end

  def list_chapter_completions(params \\ %{}) do
    ChapterCompletion
    |> where([completion], is_nil(completion.deleted_at))
    |> filter_chapter_completions(params)
    |> order_by([completion], desc: completion.completed_at)
    |> Repo.all()
  end

  def soft_delete_chapter_completion(%ChapterCompletion{} = completion, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:deleted_at, now())

    completion
    |> ChapterCompletion.changeset(attrs)
    |> Repo.update()
  end

  def change_chapter_completion(%ChapterCompletion{} = completion, attrs \\ %{}) do
    ChapterCompletion.changeset(completion, attrs)
  end

  def change_curriculum_log(%CurriculumLog{} = log, attrs \\ %{}) do
    CurriculumLog.changeset(log, attrs)
  end

  def change_chapter_exam_config(%ChapterExamConfig{} = config, attrs \\ %{}) do
    ChapterExamConfig.changeset(config, attrs)
  end

  defp filter_chapter_exam_configs(query, params) do
    Enum.reduce(params, query, fn {key, value}, acc ->
      case normalize_key(key) do
        :chapter_id -> where(acc, [config], config.chapter_id == ^value)
        :exam_track -> where(acc, [config], config.exam_track == ^value)
        _unknown -> acc
      end
    end)
  end

  defp filter_curriculum_logs(query, params) do
    Enum.reduce(params, query, fn {key, value}, acc ->
      case normalize_key(key) do
        :school_code -> where(acc, [log], log.school_code == ^value)
        :program_id -> where(acc, [log], log.program_id == ^value)
        :grade_id -> where(acc, [log], log.grade_id == ^value)
        :subject_id -> where(acc, [log], log.subject_id == ^value)
        :exam_track -> where(acc, [log], log.exam_track == ^value)
        _unknown -> acc
      end
    end)
  end

  defp filter_chapter_completions(query, params) do
    Enum.reduce(params, query, fn {key, value}, acc ->
      case normalize_key(key) do
        :school_code -> where(acc, [completion], completion.school_code == ^value)
        :program_id -> where(acc, [completion], completion.program_id == ^value)
        :chapter_id -> where(acc, [completion], completion.chapter_id == ^value)
        :exam_track -> where(acc, [completion], completion.exam_track == ^value)
        _unknown -> acc
      end
    end)
  end

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :unknown
  end

  defp normalize_key(key), do: key

  defp now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end
end
