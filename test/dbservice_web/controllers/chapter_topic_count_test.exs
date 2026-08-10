defmodule DbserviceWeb.ChapterTopicCountTest do
  @moduledoc """
  Covers the `topic_count` field on the chapters list endpoint
  (GET /api/chapter). The count is scoped to the requested curriculum_id — the
  same chapter can hold a different number of topics per curriculum (issue #633).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.ChapterCurriculums
  alias Dbservice.Chapters
  alias Dbservice.Curriculums
  alias Dbservice.TopicCurriculums
  alias Dbservice.Topics

  defp curriculum_fixture(code) do
    {:ok, curriculum} = Curriculums.create_curriculum(%{"name" => code, "code" => code})
    curriculum
  end

  defp chapter_fixture(code) do
    {:ok, chapter} = Chapters.create_chapter(%{"code" => code})
    chapter
  end

  defp link_chapter_to_curriculum(chapter, curriculum) do
    {:ok, _} =
      ChapterCurriculums.create_chapter_curriculum(%{
        chapter_id: chapter.id,
        curriculum_id: curriculum.id
      })
  end

  defp topic_fixture(chapter) do
    {:ok, topic} =
      Topics.create_topic(%{
        "code" => "TOP-#{System.unique_integer([:positive])}",
        "chapter_id" => chapter.id
      })

    topic
  end

  defp map_topic_to_curriculum(topic, curriculum) do
    {:ok, _} =
      TopicCurriculums.create_topic_curriculum(%{
        topic_id: topic.id,
        curriculum_id: curriculum.id
      })
  end

  describe "GET /api/chapter topic_count (issue #633)" do
    test "counts only topics mapped to the requested curriculum", %{conn: conn} do
      curr_a = curriculum_fixture("CURR-A-#{System.unique_integer([:positive])}")
      curr_b = curriculum_fixture("CURR-B-#{System.unique_integer([:positive])}")

      chapter = chapter_fixture("CH-#{System.unique_integer([:positive])}")
      link_chapter_to_curriculum(chapter, curr_a)
      link_chapter_to_curriculum(chapter, curr_b)

      # Two topics in curriculum A, one in curriculum B.
      t1 = topic_fixture(chapter)
      t2 = topic_fixture(chapter)
      t3 = topic_fixture(chapter)
      map_topic_to_curriculum(t1, curr_a)
      map_topic_to_curriculum(t2, curr_a)
      map_topic_to_curriculum(t3, curr_b)

      conn_a = get(conn, ~p"/api/chapter?curriculum_id=#{curr_a.id}&code=#{chapter.code}")
      assert [entry_a] = json_response(conn_a, 200)
      assert entry_a["id"] == chapter.id
      assert entry_a["topic_count"] == 2

      conn_b = get(conn, ~p"/api/chapter?curriculum_id=#{curr_b.id}&code=#{chapter.code}")
      assert [entry_b] = json_response(conn_b, 200)
      assert entry_b["topic_count"] == 1
    end

    test "returns topic_count 0 when the chapter has no topics in that curriculum", %{conn: conn} do
      curriculum = curriculum_fixture("CURR-#{System.unique_integer([:positive])}")
      chapter = chapter_fixture("CH-#{System.unique_integer([:positive])}")
      link_chapter_to_curriculum(chapter, curriculum)

      conn = get(conn, ~p"/api/chapter?curriculum_id=#{curriculum.id}&code=#{chapter.code}")
      assert [entry] = json_response(conn, 200)
      assert entry["topic_count"] == 0
    end

    test "counts all topics under the chapter when curriculum_id is omitted", %{conn: conn} do
      curriculum = curriculum_fixture("CURR-#{System.unique_integer([:positive])}")
      chapter = chapter_fixture("CH-#{System.unique_integer([:positive])}")
      link_chapter_to_curriculum(chapter, curriculum)

      t1 = topic_fixture(chapter)
      t2 = topic_fixture(chapter)
      map_topic_to_curriculum(t1, curriculum)
      # t2 has no curriculum mapping at all — still counted when unscoped.
      _ = t2

      conn = get(conn, ~p"/api/chapter?code=#{chapter.code}")
      assert [entry] = json_response(conn, 200)
      assert entry["topic_count"] == 2
    end

    test "does not double-count a topic mapped twice to the same curriculum", %{conn: conn} do
      curriculum = curriculum_fixture("CURR-#{System.unique_integer([:positive])}")
      chapter = chapter_fixture("CH-#{System.unique_integer([:positive])}")
      link_chapter_to_curriculum(chapter, curriculum)

      topic = topic_fixture(chapter)
      map_topic_to_curriculum(topic, curriculum)
      map_topic_to_curriculum(topic, curriculum)

      conn = get(conn, ~p"/api/chapter?curriculum_id=#{curriculum.id}&code=#{chapter.code}")
      assert [entry] = json_response(conn, 200)
      assert entry["topic_count"] == 1
    end
  end
end
