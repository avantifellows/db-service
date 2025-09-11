alias Dbservice.Repo
alias Dbservice.ChapterCurriculums.ChapterCurriculum
alias Dbservice.Chapters.Chapter
alias Dbservice.Curriculums.Curriculum

import Ecto.Query

IO.puts("→ Seeding chapter curriculums...")

# Get all chapters and curriculums
chapters = Repo.all(Chapter)
curriculums = Repo.all(Curriculum)

if Enum.empty?(chapters) or Enum.empty?(curriculums) do
  IO.puts("    ⚠️  No chapters or curriculums found. Skipping chapter curriculum seeding.")
else
  IO.puts("    → Found #{length(chapters)} chapters and #{length(curriculums)} curriculums")

  chapter_curriculums_created =
    for chapter <- chapters do
      # Randomly assign 1-3 curriculums to each chapter
      num_curriculums = :rand.uniform(3)
      selected_curriculums = Enum.take_random(curriculums, num_curriculums)

      for curriculum <- selected_curriculums do
        # Check if this chapter-curriculum pair already exists
        existing = Repo.get_by(ChapterCurriculum, [
          chapter_id: chapter.id,
          curriculum_id: curriculum.id
        ])

        if existing do
          0  # Already exists
        else
          chapter_curriculum_attrs = %{
            chapter_id: chapter.id,
            curriculum_id: curriculum.id,
            priority: nil,
            priority_text: nil,
            weightage: nil
          }

          case Repo.insert(%ChapterCurriculum{} |> ChapterCurriculum.changeset(chapter_curriculum_attrs)) do
            {:ok, _} -> 1
            {:error, _} -> 0
          end
        end
      end
    end
    |> List.flatten()
    |> Enum.sum()

  IO.puts("    ✅ Created #{chapter_curriculums_created} chapter curriculum associations")
end
