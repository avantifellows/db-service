alias Dbservice.LmsCurriculum.ChapterExamConfigLoader

{opts, _argv, invalid} =
  OptionParser.parse(System.argv(),
    strict: [email: :string],
    aliases: [e: :email]
  )

if invalid != [] do
  raise "Invalid arguments: #{inspect(invalid)}"
end

email = Keyword.get(opts, :email, "lms-chapter-exam-config-loader@avantifellows.org")

case ChapterExamConfigLoader.load(inserted_by_email: email) do
  {:ok, result} ->
    IO.puts(
      "Loaded #{result.upserted_count}/#{result.row_count} LMS Chapter Exam Config rows for #{result.version}."
    )

    if result.warnings != [] do
      IO.puts("Name mismatch warnings: #{length(result.warnings)}")

      Enum.each(result.warnings, fn warning ->
        IO.puts(
          "- #{warning.chapter_code}: CSV=#{inspect(warning.csv_chapter_name)} " <>
            "DB=#{inspect(warning.db_chapter_name)}"
        )
      end)
    end

  {:error, {:missing_chapter_codes, codes}} ->
    raise "Missing chapter codes: #{Enum.join(codes, ", ")}"

  {:error, {:duplicate_chapter_codes, codes}} ->
    raise "Duplicate chapter codes in DB: #{Enum.join(codes, ", ")}"

  {:error, reason} ->
    raise "Failed to load LMS Chapter Exam Config rows: #{inspect(reason)}"
end
