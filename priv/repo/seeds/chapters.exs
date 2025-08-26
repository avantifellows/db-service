alias Dbservice.Repo
alias Dbservice.Chapters.Chapter
alias Dbservice.Grades.Grade
alias Dbservice.Subjects.Subject

IO.puts("  → Seeding chapters...")

grades = Repo.all(Grade)
subjects = Repo.all(Subject)

if Enum.empty?(grades) or Enum.empty?(subjects) do
  IO.puts("    ⚠️  No grades or subjects found. Skipping chapters seeding.")
else
  chapters_data = [
    # ... your chapters_data as before ...
  ]

  chapters_created =
    for chapter_data <- chapters_data do
      grade = Enum.find(grades, fn g -> g.number == chapter_data.grade_number end)
      # Randomly pick a subject from the fetched subjects
      subject = Enum.random(subjects)

      if grade && subject do
        existing_chapter = Repo.get_by(Chapter, code: chapter_data.code)

        if existing_chapter do
          0
        else
          chapter_attrs = %{
            code: chapter_data.code,
            name: chapter_data.name,
            grade_id: grade.id,
            subject_id: subject.id
          }

          case Repo.insert(%Chapter{} |> Chapter.changeset(chapter_attrs)) do
            {:ok, _} -> 1
            {:error, _} -> 0
          end
        end
      else
        0
      end
    end
    |> Enum.sum()

  IO.puts("    ✅ Created #{chapters_created} chapters")
end
