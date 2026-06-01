defmodule Dbservice.LmsCurriculumTest do
  use Dbservice.DataCase

  alias Dbservice.Chapters.Chapter
  alias Dbservice.Grades.Grade
  alias Dbservice.LmsCurriculum
  alias Dbservice.LmsCurriculum.ChapterCompletion
  alias Dbservice.LmsCurriculum.ChapterExamConfig
  alias Dbservice.LmsCurriculum.ChapterExamConfigData
  alias Dbservice.LmsCurriculum.ChapterExamConfigLoader
  alias Dbservice.LmsCurriculum.CurriculumLog
  alias Dbservice.LmsCurriculum.CurriculumLogTopic
  alias Dbservice.Subjects.Subject
  alias Dbservice.Topics.Topic

  import Dbservice.ProgramsFixtures

  describe "chapter exam config schema" do
    test "validates configured counts and subject normalization" do
      assert ChapterExamConfigData.counts_by_subject() == %{
               "Physics" => 87,
               "Chemistry" => 96,
               "Maths" => 56,
               "Biology" => 38
             }

      assert length(ChapterExamConfigData.rows()) == 277
    end

    test "keeps all out-of-syllabus rows at zero prescribed minutes" do
      assert ChapterExamConfigData.rows()
             |> Enum.filter(&(&1.is_in_syllabus == false))
             |> Enum.all?(&(&1.prescribed_minutes == 0))
    end

    test "allows zero-minute in-syllabus rows from the source data" do
      assert Enum.any?(ChapterExamConfigData.rows(), fn row ->
               row.chapter_code == "12P29" and row.exam_track == "jee_advanced" and
                 row.is_in_syllabus == true and row.prescribed_minutes == 0
             end)
    end

    test "rejects out-of-syllabus rows with non-zero prescribed minutes" do
      chapter = chapter_fixture()

      changeset =
        ChapterExamConfig.changeset(%ChapterExamConfig{}, %{
          chapter_id: chapter.id,
          exam_track: "jee_main",
          is_in_syllabus: false,
          prescribed_minutes: 60,
          coverage_sequence: 1
        })

      refute changeset.valid?

      assert "must be 0 when the chapter is out of syllabus" in errors_on(changeset).prescribed_minutes
    end
  end

  describe "curriculum logs" do
    test "creates logs and enforces unique topics per log" do
      %{program: program, grade: grade, subject: subject, chapter: chapter} = curriculum_scope()
      topic = topic_fixture(chapter)

      assert {:ok, %CurriculumLog{} = log} =
               LmsCurriculum.create_curriculum_log(%{
                 school_code: "SCH001",
                 program_id: program.id,
                 grade_id: grade.id,
                 subject_id: subject.id,
                 exam_track: "jee_main",
                 log_date: ~D[2026-05-30],
                 duration_minutes: 45,
                 created_by_email: "teacher@avantifellows.org"
               })

      assert {:ok, %CurriculumLogTopic{}} =
               LmsCurriculum.create_curriculum_log_topic(%{
                 curriculum_log_id: log.id,
                 topic_id: topic.id
               })

      assert {:error, changeset} =
               LmsCurriculum.create_curriculum_log_topic(%{
                 curriculum_log_id: log.id,
                 topic_id: topic.id
               })

      assert %{curriculum_log_id: [_message]} = errors_on(changeset)
    end

    test "soft-deleted logs are excluded from list/get helpers" do
      %{program: program, grade: grade, subject: subject} = curriculum_scope()

      {:ok, log} =
        LmsCurriculum.create_curriculum_log(%{
          school_code: "SCH001",
          program_id: program.id,
          grade_id: grade.id,
          subject_id: subject.id,
          exam_track: "neet",
          log_date: ~D[2026-05-30],
          duration_minutes: 60
        })

      assert [_log] = LmsCurriculum.list_curriculum_logs(%{school_code: "SCH001"})
      assert %CurriculumLog{} = LmsCurriculum.get_curriculum_log(log.id)

      assert {:ok, _deleted_log} = LmsCurriculum.soft_delete_curriculum_log(log)
      assert [] = LmsCurriculum.list_curriculum_logs(%{school_code: "SCH001"})
      assert nil == LmsCurriculum.get_curriculum_log(log.id)
    end

    test "validates duration range" do
      %{program: program, grade: grade, subject: subject} = curriculum_scope()

      changeset =
        CurriculumLog.changeset(%CurriculumLog{}, %{
          school_code: "SCH001",
          program_id: program.id,
          grade_id: grade.id,
          subject_id: subject.id,
          exam_track: "jee_main",
          log_date: ~D[2026-05-30],
          duration_minutes: 721
        })

      refute changeset.valid?
      assert "must be less than or equal to 720" in errors_on(changeset).duration_minutes
    end
  end

  describe "chapter completions" do
    test "enforces active uniqueness and allows a new active row after soft delete" do
      %{program: program, chapter: chapter} = curriculum_scope()
      attrs = completion_attrs(program, chapter)

      assert {:ok, %ChapterCompletion{} = completion} =
               LmsCurriculum.create_chapter_completion(attrs)

      assert {:error, changeset} = LmsCurriculum.create_chapter_completion(attrs)
      assert %{school_code: [_message]} = errors_on(changeset)

      assert {:ok, _deleted_completion} =
               LmsCurriculum.soft_delete_chapter_completion(completion)

      assert {:ok, %ChapterCompletion{}} = LmsCurriculum.create_chapter_completion(attrs)
      assert length(LmsCurriculum.list_chapter_completions(%{school_code: "SCH001"})) == 1
    end
  end

  describe "chapter exam config loader" do
    test "loads all embedded rows and is idempotent" do
      seed_loader_chapters()

      assert {:ok, result} =
               ChapterExamConfigLoader.load(inserted_by_email: "loader@avantifellows.org")

      assert result.row_count == 277
      assert result.upserted_count == 277
      assert result.warnings == []
      assert Repo.aggregate(ChapterExamConfig, :count) == 277

      assert {:ok, second_result} =
               ChapterExamConfigLoader.load(inserted_by_email: "loader@avantifellows.org")

      assert second_result.upserted_count == 277
      assert Repo.aggregate(ChapterExamConfig, :count) == 277
    end

    test "rolls back all rows when any chapter code is missing" do
      seed_loader_chapters(missing_codes: ["12B38"])

      assert {:error, {:missing_chapter_codes, ["12B38"]}} =
               ChapterExamConfigLoader.load(inserted_by_email: "loader@avantifellows.org")

      assert Repo.aggregate(ChapterExamConfig, :count) == 0
    end

    test "reports name mismatches without aborting" do
      seed_loader_chapters(mismatch_code: "11P1")

      assert {:ok, result} =
               ChapterExamConfigLoader.load(inserted_by_email: "loader@avantifellows.org")

      assert Repo.aggregate(ChapterExamConfig, :count) == 277

      assert [
               %{
                 chapter_code: "11P1",
                 csv_chapter_name: "Mathematical Tools",
                 db_chapter_name: "Different Name"
               }
             ] = result.warnings
    end
  end

  defp curriculum_scope do
    program = program_fixture(%{name: "JNV CoE"})
    grade = grade_fixture(11)
    subject = subject_fixture("Physics")
    chapter = chapter_fixture(%{grade_id: grade.id, subject_id: subject.id})

    %{program: program, grade: grade, subject: subject, chapter: chapter}
  end

  defp completion_attrs(program, chapter) do
    %{
      school_code: "SCH001",
      program_id: program.id,
      chapter_id: chapter.id,
      exam_track: "jee_main",
      completed_by_email: "teacher@avantifellows.org"
    }
  end

  defp seed_loader_chapters(opts \\ []) do
    missing_codes = Keyword.get(opts, :missing_codes, [])
    mismatch_code = Keyword.get(opts, :mismatch_code)

    grade_by_number =
      [11, 12]
      |> Map.new(fn number ->
        grade = grade_fixture(number)
        {number, grade}
      end)

    subject_by_name =
      ["Physics", "Chemistry", "Maths", "Biology"]
      |> Map.new(fn name ->
        subject = subject_fixture(name)
        {name, subject}
      end)

    ChapterExamConfigData.rows()
    |> Enum.uniq_by(& &1.chapter_code)
    |> Enum.reject(&(&1.chapter_code in missing_codes))
    |> Enum.each(fn row ->
      chapter_name =
        if row.chapter_code == mismatch_code, do: "Different Name", else: row.chapter_name

      Repo.insert!(%Chapter{
        code: row.chapter_code,
        name: [%{"chapter" => chapter_name, "lang_code" => "en"}],
        grade_id: grade_by_number[row.grade].id,
        subject_id: subject_by_name[row.subject].id
      })
    end)
  end

  defp grade_fixture(number) do
    Repo.insert!(%Grade{number: number})
  end

  defp subject_fixture(name) do
    Repo.insert!(%Subject{
      name: [%{"subject" => name, "lang_code" => "en"}],
      code: name |> String.downcase() |> String.replace(" ", "_")
    })
  end

  defp chapter_fixture(attrs \\ %{}) do
    grade = Map.get_lazy(attrs, :grade_id, fn -> grade_fixture(11).id end)
    subject = Map.get_lazy(attrs, :subject_id, fn -> subject_fixture("Physics").id end)

    attrs =
      attrs
      |> Enum.into(%{
        code: "11P1-#{System.unique_integer([:positive])}",
        name: [%{"chapter" => "Mathematical Tools", "lang_code" => "en"}],
        grade_id: grade,
        subject_id: subject
      })

    Repo.insert!(struct(Chapter, attrs))
  end

  defp topic_fixture(chapter) do
    Repo.insert!(%Topic{
      code: "TOPIC-#{System.unique_integer([:positive])}",
      name: [%{"topic" => "Topic", "lang_code" => "en"}],
      chapter_id: chapter.id
    })
  end
end
