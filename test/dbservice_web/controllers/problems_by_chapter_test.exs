defmodule DbserviceWeb.ProblemsByChapterTest do
  @moduledoc """
  GET /api/problems lists the problems of a chapter, with topic reduced to an
  optional filter (issue #785). A problem belongs to one chapter, may carry no
  topic at all, and may be tagged with topics from other chapters — all three
  have to come out right, in both the single-language and all-languages shapes.
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Chapters
  alias Dbservice.Curriculums
  alias Dbservice.Languages
  alias Dbservice.Paragraphs
  alias Dbservice.ProblemLanguages
  alias Dbservice.ResourceChapters
  alias Dbservice.ResourceCurriculums
  alias Dbservice.ResourceTopics
  alias Dbservice.Resources
  alias Dbservice.Topics

  setup do
    language = language_fixture()
    curriculum = curriculum_fixture()
    chapter = chapter_fixture()

    %{language: language, curriculum: curriculum, chapter: chapter}
  end

  defp language_fixture do
    code = "l#{System.unique_integer([:positive])}"
    {:ok, language} = Languages.create_language(%{"name" => "Lang #{code}", "code" => code})
    language
  end

  defp curriculum_fixture do
    {:ok, curriculum} =
      Curriculums.create_curriculum(%{
        "name" => "Curriculum",
        "code" => "CURR-#{System.unique_integer([:positive])}"
      })

    curriculum
  end

  defp chapter_fixture do
    {:ok, chapter} =
      Chapters.create_chapter(%{"code" => "CH-#{System.unique_integer([:positive])}"})

    chapter
  end

  defp topic_fixture(chapter) do
    {:ok, topic} =
      Topics.create_topic(%{
        "code" => "TOP-#{System.unique_integer([:positive])}",
        "chapter_id" => chapter.id
      })

    topic
  end

  # Builds a listable problem: a resource, its curriculum row, its chapter row,
  # any topic tags, and one problem_lang row so the single-language shape finds it.
  defp problem_fixture(ctx, opts \\ []) do
    attrs =
      %{"type" => "problem", "type_params" => %{}}
      |> Map.merge(Keyword.get(opts, :attrs, %{}))

    {:ok, resource} = Resources.create_resource(attrs)

    {:ok, _} =
      ResourceCurriculums.create_resource_curriculum(%{
        resource_id: resource.id,
        curriculum_id: ctx.curriculum.id,
        difficulty_level: "medium"
      })

    case Keyword.get(opts, :chapter, ctx.chapter) do
      nil ->
        :ok

      chapter ->
        {:ok, _} =
          ResourceChapters.create_resource_chapter(%{
            resource_id: resource.id,
            chapter_id: chapter.id
          })
    end

    Enum.each(Keyword.get(opts, :topics, []), fn topic ->
      {:ok, _} =
        ResourceTopics.create_resource_topic(%{resource_id: resource.id, topic_id: topic.id})
    end)

    {:ok, _} =
      ProblemLanguages.create_problem_language(%{
        res_id: resource.id,
        lang_id: ctx.language.id,
        meta_data: %{"text" => "q"},
        paragraph_id: Keyword.get(opts, :paragraph_id)
      })

    resource
  end

  defp list(conn, params) do
    conn |> get(~p"/api/problems", params) |> json_response(200) |> Enum.map(& &1["id"])
  end

  # Every assertion below is run twice: once asking for a single language and
  # once for all languages, since the two shapes are built from separate queries.
  defp list_both(conn, ctx, params) do
    {list(conn, Map.put(params, "lang_code", ctx.language.code)), list(conn, params)}
  end

  describe "chapter_id" do
    test "is required", %{conn: conn} do
      conn = get(conn, ~p"/api/problems", %{})
      assert json_response(conn, 422)["error"] == "chapter_id is required"
    end

    test "lists the problems of that chapter and nothing else", %{conn: conn} = ctx do
      mine = problem_fixture(ctx)
      elsewhere = problem_fixture(ctx, chapter: chapter_fixture())

      {single, all} = list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id})

      assert single == [mine.id]
      assert all == [mine.id]
      refute elsewhere.id in single
    end

    test "lists a problem that has no topic at all", %{conn: conn} = ctx do
      problem = problem_fixture(ctx, topics: [])

      {single, all} = list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id})

      assert single == [problem.id]
      assert all == [problem.id]
    end

    test "lists a multi-topic problem exactly once", %{conn: conn} = ctx do
      topics = [topic_fixture(ctx.chapter), topic_fixture(ctx.chapter)]
      problem = problem_fixture(ctx, topics: topics)

      {single, all} = list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id})

      assert single == [problem.id]
      assert all == [problem.id]
    end

    test "still applies curriculum_id when it is given", %{conn: conn} = ctx do
      problem = problem_fixture(ctx)

      assert list(conn, %{"chapter_id" => ctx.chapter.id, "curriculum_id" => ctx.curriculum.id}) ==
               [problem.id]

      assert list(conn, %{
               "chapter_id" => ctx.chapter.id,
               "curriculum_id" => curriculum_fixture().id
             }) == []
    end
  end

  describe "topic_id filter" do
    test "narrows the chapter listing to problems tagged with that topic",
         %{conn: conn} = ctx do
      wanted = topic_fixture(ctx.chapter)
      other = topic_fixture(ctx.chapter)

      tagged = problem_fixture(ctx, topics: [wanted])
      _other_topic = problem_fixture(ctx, topics: [other])
      _untagged = problem_fixture(ctx, topics: [])

      {single, all} =
        list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id, "topic_id" => wanted.id})

      assert single == [tagged.id]
      assert all == [tagged.id]
    end

    test "returns a multi-topic problem once, not once per topic", %{conn: conn} = ctx do
      wanted = topic_fixture(ctx.chapter)
      problem = problem_fixture(ctx, topics: [wanted, topic_fixture(ctx.chapter)])

      {single, all} =
        list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id, "topic_id" => wanted.id})

      assert single == [problem.id]
      assert all == [problem.id]
    end

    # A problem lives in its own chapter but may be tagged with a topic from
    # another one. It must stay under its own chapter, and be findable by that
    # foreign topic from there — never from the topic's chapter.
    test "works for a topic belonging to another chapter", %{conn: conn} = ctx do
      other_chapter = chapter_fixture()
      foreign_topic = topic_fixture(other_chapter)
      problem = problem_fixture(ctx, topics: [foreign_topic])

      {own_chapter, own_chapter_all} =
        list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id, "topic_id" => foreign_topic.id})

      assert own_chapter == [problem.id]
      assert own_chapter_all == [problem.id]

      {topics_chapter, topics_chapter_all} =
        list_both(conn, ctx, %{"chapter_id" => other_chapter.id, "topic_id" => foreign_topic.id})

      assert topics_chapter == []
      assert topics_chapter_all == []
    end

    test "returns nothing when no problem in the chapter carries the topic",
         %{conn: conn} = ctx do
      problem_fixture(ctx, topics: [topic_fixture(ctx.chapter)])
      unused_topic = topic_fixture(ctx.chapter)

      {single, all} =
        list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id, "topic_id" => unused_topic.id})

      assert single == []
      assert all == []
    end
  end

  describe "legacy topic-only request" do
    test "still lists by topic across chapters", %{conn: conn} = ctx do
      topic = topic_fixture(ctx.chapter)
      here = problem_fixture(ctx, topics: [topic])
      elsewhere = problem_fixture(ctx, chapter: chapter_fixture(), topics: [topic])
      _untagged = problem_fixture(ctx, topics: [])

      {single, all} = list_both(conn, ctx, %{"topic_id" => topic.id})

      assert Enum.sort(single) == Enum.sort([here.id, elsewhere.id])
      assert Enum.sort(all) == Enum.sort([here.id, elsewhere.id])
    end

    # The backfill migration leaves no chapterless problem behind, but the legacy
    # path must not quietly start depending on that.
    test "still lists a problem that has no chapter row", %{conn: conn} = ctx do
      topic = topic_fixture(ctx.chapter)
      problem = problem_fixture(ctx, chapter: nil, topics: [topic])

      {single, all} = list_both(conn, ctx, %{"topic_id" => topic.id})

      assert single == [problem.id]
      assert all == [problem.id]
    end
  end

  describe "include_paragraph_siblings" do
    test "pulls in a comprehension problem from another chapter sharing the paragraph",
         %{conn: conn} = ctx do
      {:ok, paragraph} = Paragraphs.create_paragraph(%{"body" => "shared passage"})
      comprehension = %{"subtype" => "comprehension"}

      in_chapter =
        problem_fixture(ctx, attrs: comprehension, paragraph_id: paragraph.id)

      sibling =
        problem_fixture(ctx,
          attrs: comprehension,
          chapter: chapter_fixture(),
          paragraph_id: paragraph.id
        )

      {single, all} =
        list_both(conn, ctx, %{
          "chapter_id" => ctx.chapter.id,
          "include_paragraph_siblings" => "true"
        })

      assert Enum.sort(single) == Enum.sort([in_chapter.id, sibling.id])
      assert Enum.sort(all) == Enum.sort([in_chapter.id, sibling.id])
    end

    test "is off by default", %{conn: conn} = ctx do
      {:ok, paragraph} = Paragraphs.create_paragraph(%{"body" => "shared passage"})
      comprehension = %{"subtype" => "comprehension"}

      in_chapter = problem_fixture(ctx, attrs: comprehension, paragraph_id: paragraph.id)

      problem_fixture(ctx,
        attrs: comprehension,
        chapter: chapter_fixture(),
        paragraph_id: paragraph.id
      )

      {single, all} = list_both(conn, ctx, %{"chapter_id" => ctx.chapter.id})

      assert single == [in_chapter.id]
      assert all == [in_chapter.id]
    end
  end

  describe "response shape" do
    test "carries the problem's own chapter_id and all its topics", %{conn: conn} = ctx do
      foreign_topic = topic_fixture(chapter_fixture())
      own_topic = topic_fixture(ctx.chapter)
      problem = problem_fixture(ctx, topics: [own_topic, foreign_topic])

      [listed] =
        conn
        |> get(~p"/api/problems", %{
          "chapter_id" => ctx.chapter.id,
          "lang_code" => ctx.language.code
        })
        |> json_response(200)

      assert listed["id"] == problem.id
      assert listed["chapter_id"] == ctx.chapter.id
      assert Enum.sort(listed["topic_ids"]) == Enum.sort([own_topic.id, foreign_topic.id])
      assert listed["topic_id"] in [own_topic.id, foreign_topic.id]
    end
  end
end
