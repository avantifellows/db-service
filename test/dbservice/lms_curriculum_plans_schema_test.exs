defmodule Dbservice.LmsCurriculumPlansSchemaTest do
  use Dbservice.DataCase, async: true

  alias Dbservice.Chapters.Chapter
  alias Dbservice.LmsCurriculum.CurriculumPlan
  alias Dbservice.LmsCurriculum.CurriculumPlanAssignment
  alias Dbservice.LmsCurriculum.CurriculumPlanChapter

  import Dbservice.GradesFixtures

  describe "lms_curriculum_plans" do
    test "defaults status to draft and stamps UTC timestamps" do
      grade = grade_fixture(%{number: 11})

      {:ok, %{rows: [["draft", inserted_at, updated_at, nil]]}} =
        Repo.query(
          """
          INSERT INTO lms_curriculum_plans (title, academic_year, grade_id, exam_tracks, closure_date)
          VALUES ('G11 Others', '2026-2027', $1, ARRAY['jee_main', 'neet'], '2027-03-31')
          RETURNING status, inserted_at, updated_at, activated_at
          """,
          [grade.id]
        )

      assert %NaiveDateTime{} = inserted_at
      assert %NaiveDateTime{} = updated_at
    end

    test "rejects statuses other than draft and active" do
      grade = grade_fixture(%{number: 11})

      assert {:ok, _} = insert_plan(grade.id, status: "active")
      assert_constraint(:check_violation, fn -> insert_plan(grade.id, status: "closed") end)
      assert_constraint(:check_violation, fn -> insert_plan(grade.id, status: "archived") end)
    end

    test "requires a non-empty subset of the three content Exam Tracks" do
      grade = grade_fixture(%{number: 11})

      assert {:ok, _} =
               insert_plan(grade.id, exam_tracks: ["jee_main", "jee_advanced", "neet"])

      assert_constraint(:check_violation, fn -> insert_plan(grade.id, exam_tracks: []) end)

      assert_constraint(:check_violation, fn ->
        insert_plan(grade.id, exam_tracks: ["jee_main", "cet"])
      end)

      assert_constraint(:check_violation, fn ->
        insert_plan(grade.id, exam_tracks: ["math_foundation"])
      end)
    end

    test "requires a consecutive YYYY-YYYY academic year and a non-blank title" do
      grade = grade_fixture(%{number: 11})

      assert_constraint(:check_violation, fn ->
        insert_plan(grade.id, academic_year: "2026-2028")
      end)

      assert_constraint(:check_violation, fn ->
        insert_plan(grade.id, academic_year: "2026-2025")
      end)

      assert_constraint(:check_violation, fn -> insert_plan(grade.id, title: "   ") end)
    end

    test "rejects an unknown Grade" do
      assert_constraint(:foreign_key_violation, fn -> insert_plan(-1) end)
    end

    test "changeset mirrors the database rules" do
      grade = grade_fixture(%{number: 11})

      valid = %{
        title: "G12",
        academic_year: "2026-2027",
        grade_id: grade.id,
        exam_tracks: ["jee_main"],
        closure_date: ~D[2027-03-31]
      }

      assert CurriculumPlan.changeset(%CurriculumPlan{}, valid).valid?

      errors =
        %CurriculumPlan{}
        |> CurriculumPlan.changeset(%{
          valid
          | academic_year: "2026-2028",
            exam_tracks: ["cet"]
        })
        |> Map.put(:action, :insert)
        |> errors_on()

      assert errors.academic_year == ["must be two consecutive years, e.g. 2026-2027"]
      assert [_] = errors.exam_tracks

      assert %{status: [_]} =
               errors_on(
                 CurriculumPlan.changeset(%CurriculumPlan{}, Map.put(valid, :status, "closed"))
               )

      assert %{exam_tracks: [_]} =
               errors_on(CurriculumPlan.changeset(%CurriculumPlan{}, %{valid | exam_tracks: []}))

      assert {:error, changeset} =
               %CurriculumPlan{}
               |> CurriculumPlan.changeset(%{valid | grade_id: -1})
               |> Repo.insert()

      assert %{grade_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "lms_curriculum_plan_chapters" do
    test "a Chapter Test Date requires a Chapter Due Date" do
      %{plan_id: plan_id, chapter_id: chapter_id} = plan_with_chapter()

      assert_constraint(:check_violation, fn ->
        insert_plan_chapter(plan_id, chapter_id, nil, ~D[2026-08-10])
      end)

      assert {:ok, _} = insert_plan_chapter(plan_id, chapter_id, nil, nil)

      assert {:ok, %{num_rows: 1}} =
               Repo.query(
                 "UPDATE lms_curriculum_plan_chapters SET due_date = '2026-08-01', test_date = '2026-08-10'"
               )

      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE lms_curriculum_plan_chapters SET due_date = NULL")
      end)
    end

    test "keeps one row per plan and Chapter, so ON CONFLICT (plan_id, chapter_id) upserts" do
      %{plan_id: plan_id, chapter_id: chapter_id} = plan_with_chapter()

      assert {:ok, _} = insert_plan_chapter(plan_id, chapter_id, ~D[2026-08-01], nil)

      assert_constraint(:unique_violation, fn ->
        insert_plan_chapter(plan_id, chapter_id, ~D[2026-09-01], nil)
      end)

      assert {:ok, %{rows: [[~D[2026-09-01], ~D[2026-09-05]]]}} =
               Repo.query(
                 """
                 INSERT INTO lms_curriculum_plan_chapters (plan_id, chapter_id, due_date, test_date)
                 VALUES ($1, $2, '2026-09-01', '2026-09-05')
                 ON CONFLICT (plan_id, chapter_id) DO UPDATE SET
                   due_date = EXCLUDED.due_date, test_date = EXCLUDED.test_date
                 RETURNING due_date, test_date
                 """,
                 [plan_id, chapter_id]
               )
    end

    test "rejects an unknown plan or Chapter" do
      %{plan_id: plan_id, chapter_id: chapter_id} = plan_with_chapter()

      assert_constraint(:foreign_key_violation, fn ->
        insert_plan_chapter(-1, chapter_id, nil, nil)
      end)

      assert_constraint(:foreign_key_violation, fn ->
        insert_plan_chapter(plan_id, -1, nil, nil)
      end)
    end

    test "changeset maps the test-date and unique rules" do
      %{plan_id: plan_id, chapter_id: chapter_id} = plan_with_chapter()
      attrs = %{plan_id: plan_id, chapter_id: chapter_id, test_date: ~D[2026-08-10]}

      assert %{test_date: ["requires a due date"]} =
               errors_on(CurriculumPlanChapter.changeset(%CurriculumPlanChapter{}, attrs))

      attrs = Map.put(attrs, :due_date, ~D[2026-08-01])

      assert {:ok, _} =
               %CurriculumPlanChapter{}
               |> CurriculumPlanChapter.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %CurriculumPlanChapter{}
               |> CurriculumPlanChapter.changeset(attrs)
               |> Repo.insert()

      assert %{plan_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "lms_curriculum_plan_assignments" do
    test "allows one plan per Centre + Grade + academic year" do
      grade = grade_fixture(%{number: 11})
      other_grade = grade_fixture(%{number: 12})
      centre_id = insert_centre()
      {:ok, %{rows: [[plan_id]]}} = insert_plan(grade.id)
      {:ok, %{rows: [[other_plan_id]]}} = insert_plan(grade.id, title: "G11 HYD")

      assert {:ok, _} = insert_assignment(plan_id, centre_id, grade.id, "2026-2027")

      assert_constraint(:unique_violation, fn ->
        insert_assignment(other_plan_id, centre_id, grade.id, "2026-2027")
      end)

      assert {:ok, _} = insert_assignment(other_plan_id, centre_id, grade.id, "2027-2028")
      assert {:ok, _} = insert_assignment(other_plan_id, centre_id, other_grade.id, "2026-2027")
    end

    test "rejects an unknown plan, Centre or Grade" do
      grade = grade_fixture(%{number: 11})
      centre_id = insert_centre()
      {:ok, %{rows: [[plan_id]]}} = insert_plan(grade.id)

      assert_constraint(:foreign_key_violation, fn ->
        insert_assignment(-1, centre_id, grade.id, "2026-2027")
      end)

      assert_constraint(:foreign_key_violation, fn ->
        insert_assignment(plan_id, -1, grade.id, "2026-2027")
      end)

      assert_constraint(:foreign_key_violation, fn ->
        insert_assignment(plan_id, centre_id, -1, "2026-2027")
      end)
    end

    test "changeset maps the unique and Centre foreign key rules" do
      grade = grade_fixture(%{number: 11})
      centre_id = insert_centre()
      {:ok, %{rows: [[plan_id]]}} = insert_plan(grade.id)

      attrs = %{
        plan_id: plan_id,
        centre_id: centre_id,
        grade_id: grade.id,
        academic_year: "2026-2027"
      }

      assert {:ok, _} =
               %CurriculumPlanAssignment{}
               |> CurriculumPlanAssignment.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %CurriculumPlanAssignment{}
               |> CurriculumPlanAssignment.changeset(attrs)
               |> Repo.insert()

      assert %{centre_id: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               %CurriculumPlanAssignment{}
               |> CurriculumPlanAssignment.changeset(%{attrs | centre_id: -1})
               |> Repo.insert()

      assert %{centre_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "deleting a plan" do
    test "cascades to its plan chapters and assignments only" do
      %{plan_id: plan_id, chapter_id: chapter_id, grade_id: grade_id} = plan_with_chapter()
      {:ok, %{rows: [[kept_plan_id]]}} = insert_plan(grade_id, title: "Kept")
      centre_id = insert_centre()
      other_centre_id = insert_centre()

      {:ok, _} = insert_plan_chapter(plan_id, chapter_id, ~D[2026-08-01], nil)
      {:ok, _} = insert_plan_chapter(kept_plan_id, chapter_id, ~D[2026-08-01], nil)
      {:ok, _} = insert_assignment(plan_id, centre_id, grade_id, "2026-2027")
      {:ok, _} = insert_assignment(kept_plan_id, other_centre_id, grade_id, "2026-2027")

      assert {:ok, %{num_rows: 1}} =
               Repo.query("DELETE FROM lms_curriculum_plans WHERE id = $1", [plan_id])

      assert count("lms_curriculum_plan_chapters", plan_id) == 0
      assert count("lms_curriculum_plan_assignments", plan_id) == 0
      assert count("lms_curriculum_plan_chapters", kept_plan_id) == 1
      assert count("lms_curriculum_plan_assignments", kept_plan_id) == 1
    end

    test "a referenced Chapter, Grade or Centre cannot be deleted" do
      %{plan_id: plan_id, chapter_id: chapter_id} = plan_with_chapter()
      centre_id = insert_centre()
      plan_grade = grade_fixture(%{number: 12})
      assignment_grade = grade_fixture(%{number: 10})
      {:ok, _} = insert_plan(plan_grade.id)
      {:ok, _} = insert_plan_chapter(plan_id, chapter_id, nil, nil)
      {:ok, _} = insert_assignment(plan_id, centre_id, assignment_grade.id, "2026-2027")

      assert_constraint(
        :foreign_key_violation,
        "lms_curriculum_plan_chapters_chapter_id_fkey",
        fn ->
          Repo.query("DELETE FROM chapter WHERE id = $1", [chapter_id])
        end
      )

      assert_constraint(
        :foreign_key_violation,
        "lms_curriculum_plan_assignments_centre_id_fkey",
        fn ->
          Repo.query("DELETE FROM centres WHERE id = $1", [centre_id])
        end
      )

      assert_constraint(:foreign_key_violation, "lms_curriculum_plans_grade_id_fkey", fn ->
        Repo.query("DELETE FROM grade WHERE id = $1", [plan_grade.id])
      end)

      assert_constraint(
        :foreign_key_violation,
        "lms_curriculum_plan_assignments_grade_id_fkey",
        fn ->
          Repo.query("DELETE FROM grade WHERE id = $1", [assignment_grade.id])
        end
      )
    end
  end

  test "constraint names and delete rules match the af_lms e2e fixture" do
    assert db_constraints("lms_curriculum_plans") == [
             {"lms_curriculum_plans_academic_year_check", "c", nil},
             {"lms_curriculum_plans_exam_tracks_check", "c", nil},
             {"lms_curriculum_plans_grade_id_fkey", "f", "a"},
             {"lms_curriculum_plans_pkey", "p", nil},
             {"lms_curriculum_plans_status_check", "c", nil},
             {"lms_curriculum_plans_title_check", "c", nil}
           ]

    assert db_constraints("lms_curriculum_plan_chapters") == [
             {"lms_curriculum_plan_chapters_chapter_id_fkey", "f", "a"},
             {"lms_curriculum_plan_chapters_pkey", "p", nil},
             {"lms_curriculum_plan_chapters_plan_id_chapter_id_index", "u", nil},
             {"lms_curriculum_plan_chapters_plan_id_fkey", "f", "c"},
             {"lms_curriculum_plan_chapters_test_date_requires_due_date", "c", nil}
           ]

    assert db_constraints("lms_curriculum_plan_assignments") == [
             {"lms_curriculum_plan_assignments_centre_grade_year_index", "u", nil},
             {"lms_curriculum_plan_assignments_centre_id_fkey", "f", "a"},
             {"lms_curriculum_plan_assignments_grade_id_fkey", "f", "a"},
             {"lms_curriculum_plan_assignments_pkey", "p", nil},
             {"lms_curriculum_plan_assignments_plan_id_fkey", "f", "c"}
           ]

    assert %{rows: rows} =
             Repo.query!("""
             SELECT indexname FROM pg_indexes
             WHERE tablename IN ('lms_curriculum_plans', 'lms_curriculum_plan_assignments')
               AND indexname IN (
                 'lms_curriculum_plans_academic_year_grade_index',
                 'lms_curriculum_plan_assignments_plan_id_index'
               )
             ORDER BY indexname
             """)

    assert rows == [
             ["lms_curriculum_plan_assignments_plan_id_index"],
             ["lms_curriculum_plans_academic_year_grade_index"]
           ]
  end

  defp db_constraints(table) do
    Repo.query!(
      """
      SELECT conname, contype::text, NULLIF(confdeltype::text, ' ')
      FROM pg_constraint
      WHERE conrelid = $1::text::regclass
      ORDER BY conname
      """,
      [table]
    ).rows
    |> Enum.map(&List.to_tuple/1)
  end

  defp plan_with_chapter do
    grade = grade_fixture(%{number: 11})
    {:ok, %{rows: [[plan_id]]}} = insert_plan(grade.id)

    chapter =
      Repo.insert!(%Chapter{
        code: "11P1-#{System.unique_integer([:positive])}",
        name: [%{"chapter" => "Mathematical Tools", "lang_code" => "en"}],
        grade_id: grade.id
      })

    %{plan_id: plan_id, chapter_id: chapter.id, grade_id: grade.id}
  end

  defp insert_plan(grade_id, opts \\ []) do
    Repo.query(
      """
      INSERT INTO lms_curriculum_plans
        (title, academic_year, grade_id, exam_tracks, status, closure_date, inserted_by_email)
      VALUES ($1, $2, $3, $4, $5, '2027-03-31', 'admin@avantifellows.org')
      RETURNING id
      """,
      [
        Keyword.get(opts, :title, "G11 Others"),
        Keyword.get(opts, :academic_year, "2026-2027"),
        grade_id,
        Keyword.get(opts, :exam_tracks, ["jee_main", "neet"]),
        Keyword.get(opts, :status, "draft")
      ]
    )
  end

  defp insert_plan_chapter(plan_id, chapter_id, due_date, test_date) do
    Repo.query(
      """
      INSERT INTO lms_curriculum_plan_chapters (plan_id, chapter_id, due_date, test_date)
      VALUES ($1, $2, $3, $4)
      """,
      [plan_id, chapter_id, due_date, test_date]
    )
  end

  defp insert_assignment(plan_id, centre_id, grade_id, academic_year) do
    Repo.query(
      """
      INSERT INTO lms_curriculum_plan_assignments (plan_id, centre_id, grade_id, academic_year)
      VALUES ($1, $2, $3, $4)
      """,
      [plan_id, centre_id, grade_id, academic_year]
    )
  end

  defp insert_centre do
    Repo.query!("INSERT INTO centres (name) VALUES ('JNV Bharuch') RETURNING id").rows
    |> hd()
    |> hd()
  end

  defp count(table, plan_id) do
    [[count]] =
      Repo.query!("SELECT count(*) FROM #{table} WHERE plan_id = $1", [plan_id]).rows

    count
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end

  defp assert_constraint(code, name, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code, constraint: ^name}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
