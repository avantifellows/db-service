defmodule Mix.Tasks.Lms.LoadChapterExamConfigs do
  @moduledoc """
  Loads the embedded 2026-27 LMS Chapter Exam Config dataset.

      mix lms.load_chapter_exam_configs
      mix lms.load_chapter_exam_configs --email teacher@avantifellows.org
  """

  use Mix.Task

  alias Dbservice.LmsCurriculum.ChapterExamConfigLoader

  @shortdoc "Loads LMS Chapter Exam Config rows"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [email: :string],
        aliases: [e: :email]
      )

    email = Keyword.get(opts, :email, "lms-chapter-exam-config-loader@avantifellows.org")

    case ChapterExamConfigLoader.load(inserted_by_email: email) do
      {:ok, result} ->
        Mix.shell().info(
          "Loaded #{result.upserted_count}/#{result.row_count} LMS Chapter Exam Config rows " <>
            "for #{result.version}."
        )

        if result.warnings != [] do
          Mix.shell().info("Name mismatch warnings: #{length(result.warnings)}")

          Enum.each(result.warnings, fn warning ->
            Mix.shell().info(
              "- #{warning.chapter_code}: CSV=#{inspect(warning.csv_chapter_name)} " <>
                "DB=#{inspect(warning.db_chapter_name)}"
            )
          end)
        end

      {:error, {:missing_chapter_codes, codes}} ->
        Mix.raise("Missing chapter codes: #{Enum.join(codes, ", ")}")

      {:error, {:duplicate_chapter_codes, codes}} ->
        Mix.raise("Duplicate chapter codes in DB: #{Enum.join(codes, ", ")}")

      {:error, reason} ->
        Mix.raise("Failed to load LMS Chapter Exam Config rows: #{inspect(reason)}")
    end
  end
end
