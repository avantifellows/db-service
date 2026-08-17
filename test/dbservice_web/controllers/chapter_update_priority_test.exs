defmodule DbserviceWeb.ChapterUpdatePriorityTest do
  @moduledoc """
  PATCH /api/chapter/:id must update curriculum-scoped fields
  (priority/priority_text/weightage) on the chapter_curriculum row for the given
  curriculum_id, not just the chapter table (issue #688).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.ChapterCurriculums
  alias Dbservice.Chapters
  alias Dbservice.Curriculums

  defp curriculum_fixture do
    code = "CURR-#{System.unique_integer([:positive])}"
    {:ok, curriculum} = Curriculums.create_curriculum(%{"name" => code, "code" => code})
    curriculum
  end

  defp chapter_fixture do
    {:ok, chapter} =
      Chapters.create_chapter(%{"code" => "CH-#{System.unique_integer([:positive])}"})

    chapter
  end

  defp link_chapter_to_curriculum(chapter, curriculum, attrs) do
    {:ok, cc} =
      ChapterCurriculums.create_chapter_curriculum(
        Map.merge(%{chapter_id: chapter.id, curriculum_id: curriculum.id}, attrs)
      )

    cc
  end

  defp curriculum_entry(body, curriculum_id) do
    Enum.find(body["curriculums"], &(&1["curriculum_id"] == curriculum_id))
  end

  describe "PATCH /api/chapter/:id (issue #688)" do
    test "updates priority/priority_text on the matching chapter_curriculum row", %{conn: conn} do
      curriculum = curriculum_fixture()
      chapter = chapter_fixture()
      link_chapter_to_curriculum(chapter, curriculum, %{priority: 2, priority_text: "medium"})

      conn =
        patch(conn, ~p"/api/chapter/#{chapter.id}", %{
          "curriculum_id" => curriculum.id,
          "priority" => 3,
          "priority_text" => "low"
        })

      body = json_response(conn, 200)
      entry = curriculum_entry(body, curriculum.id)
      assert entry["priority"] == 3
      assert entry["priority_text"] == "low"
    end

    test "only touches the row for the requested curriculum_id", %{conn: conn} do
      curr1 = curriculum_fixture()
      curr2 = curriculum_fixture()
      chapter = chapter_fixture()
      link_chapter_to_curriculum(chapter, curr1, %{priority: 2, priority_text: "medium"})
      link_chapter_to_curriculum(chapter, curr2, %{priority: 1, priority_text: "high"})

      conn =
        patch(conn, ~p"/api/chapter/#{chapter.id}", %{
          "curriculum_id" => curr1.id,
          "priority" => 3,
          "priority_text" => "low"
        })

      body = json_response(conn, 200)
      assert curriculum_entry(body, curr1.id)["priority"] == 3
      assert curriculum_entry(body, curr1.id)["priority_text"] == "low"
      # The other curriculum's mapping is left untouched.
      assert curriculum_entry(body, curr2.id)["priority"] == 1
      assert curriculum_entry(body, curr2.id)["priority_text"] == "high"
    end

    test "creates a chapter_curriculum row when none exists for the curriculum_id",
         %{conn: conn} do
      curriculum = curriculum_fixture()
      chapter = chapter_fixture()

      conn =
        patch(conn, ~p"/api/chapter/#{chapter.id}", %{
          "curriculum_id" => curriculum.id,
          "priority" => 5,
          "priority_text" => "lowest"
        })

      body = json_response(conn, 200)
      entry = curriculum_entry(body, curriculum.id)
      assert entry["priority"] == 5
      assert entry["priority_text"] == "lowest"
    end

    test "still updates base chapter fields when no curriculum_id is given", %{conn: conn} do
      chapter = chapter_fixture()

      conn =
        patch(conn, ~p"/api/chapter/#{chapter.id}", %{
          "code" => "CH-RENAMED-#{System.unique_integer([:positive])}"
        })

      body = json_response(conn, 200)
      assert body["id"] == chapter.id
      assert String.starts_with?(body["code"], "CH-RENAMED-")
    end
  end
end
