defmodule Dbservice.LmsCurriculum.ChapterExamConfigLoader do
  @moduledoc """
  One-time loader for the embedded LMS Chapter Exam Config dataset.
  """

  require Logger
  import Ecto.Query, warn: false

  alias Dbservice.Chapters.Chapter
  alias Dbservice.LmsCurriculum.ChapterExamConfig
  alias Dbservice.LmsCurriculum.ChapterExamConfigData
  alias Dbservice.Repo

  @default_email "lms-chapter-exam-config-loader@avantifellows.org"

  def load(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    inserted_by_email = Keyword.get(opts, :inserted_by_email, @default_email)
    updated_by_email = Keyword.get(opts, :updated_by_email, inserted_by_email)
    rows = Keyword.get(opts, :rows, ChapterExamConfigData.rows())

    with :ok <- validate_embedded_counts(rows) do
      repo.transaction(fn ->
        chapter_map = chapter_map(repo, rows)

        case validate_chapters(rows, chapter_map) do
          :ok ->
            warnings = name_mismatch_warnings(rows, chapter_map)
            Enum.each(warnings, fn warning -> Logger.warning(format_warning(warning)) end)

            {count, _} =
              repo.insert_all(
                ChapterExamConfig,
                upsert_rows(rows, chapter_map, inserted_by_email, updated_by_email),
                conflict_target: [:chapter_id, :exam_track],
                on_conflict: {:replace, conflict_replace_fields()}
              )

            %{
              version: ChapterExamConfigData.version(),
              row_count: length(rows),
              upserted_count: count,
              warnings: warnings
            }

          {:error, reason} ->
            repo.rollback(reason)
        end
      end)
    end
  end

  defp validate_embedded_counts(rows) do
    actual_counts =
      rows
      |> Enum.group_by(& &1.subject)
      |> Map.new(fn {subject, rows} -> {subject, length(rows)} end)

    if actual_counts == ChapterExamConfigData.expected_counts() and length(rows) == 277 do
      :ok
    else
      {:error, {:invalid_embedded_counts, actual_counts}}
    end
  end

  defp chapter_map(repo, rows) do
    codes = rows |> Enum.map(& &1.chapter_code) |> Enum.uniq()

    Chapter
    |> where([chapter], chapter.code in ^codes)
    |> repo.all()
    |> Enum.group_by(& &1.code)
  end

  defp validate_chapters(rows, chapter_map) do
    expected_codes = rows |> Enum.map(& &1.chapter_code) |> Enum.uniq() |> Enum.sort()

    missing_codes =
      expected_codes
      |> Enum.reject(&Map.has_key?(chapter_map, &1))

    duplicate_codes =
      chapter_map
      |> Enum.filter(fn {_code, chapters} -> length(chapters) > 1 end)
      |> Enum.map(fn {code, _chapters} -> code end)
      |> Enum.sort()

    cond do
      missing_codes != [] -> {:error, {:missing_chapter_codes, missing_codes}}
      duplicate_codes != [] -> {:error, {:duplicate_chapter_codes, duplicate_codes}}
      true -> :ok
    end
  end

  defp name_mismatch_warnings(rows, chapter_map) do
    rows
    |> Enum.uniq_by(& &1.chapter_code)
    |> Enum.reduce([], fn row, warnings ->
      chapter = chapter_map |> Map.fetch!(row.chapter_code) |> List.first()
      db_name = chapter_name(chapter)

      if normalize_name(db_name) == normalize_name(row.chapter_name) do
        warnings
      else
        [
          %{
            chapter_code: row.chapter_code,
            csv_chapter_name: row.chapter_name,
            db_chapter_name: db_name
          }
          | warnings
        ]
      end
    end)
    |> Enum.reverse()
  end

  defp upsert_rows(rows, chapter_map, inserted_by_email, updated_by_email) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Enum.map(rows, fn row ->
      chapter = chapter_map |> Map.fetch!(row.chapter_code) |> List.first()

      %{
        chapter_id: chapter.id,
        exam_track: row.exam_track,
        is_in_syllabus: row.is_in_syllabus,
        prescribed_minutes: row.prescribed_minutes,
        coverage_sequence: row.coverage_sequence,
        inserted_by_email: inserted_by_email,
        updated_by_email: updated_by_email,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp conflict_replace_fields do
    [
      :is_in_syllabus,
      :prescribed_minutes,
      :coverage_sequence,
      :updated_by_email,
      :updated_at
    ]
  end

  defp chapter_name(%Chapter{name: names}) when is_list(names) do
    english_name =
      Enum.find_value(names, fn
        %{"lang_code" => "en", "chapter" => chapter} -> chapter
        %{lang_code: "en", chapter: chapter} -> chapter
        _other -> nil
      end)

    english_name ||
      Enum.find_value(names, fn
        %{"chapter" => chapter} -> chapter
        %{chapter: chapter} -> chapter
        _other -> nil
      end)
  end

  defp chapter_name(%Chapter{name: name}) when is_binary(name), do: name
  defp chapter_name(_chapter), do: nil

  defp normalize_name(nil), do: ""

  defp normalize_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, " ")
    |> String.trim()
  end

  defp format_warning(warning) do
    "LMS Chapter Exam Config name mismatch for #{warning.chapter_code}: " <>
      "CSV=#{inspect(warning.csv_chapter_name)} DB=#{inspect(warning.db_chapter_name)}"
  end
end
