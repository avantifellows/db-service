defmodule DbserviceWeb.ResourceMultipleTopicsTest do
  @moduledoc """
  A problem belongs to exactly one chapter but may be mapped to any number of
  topics, including topics from other chapters (issue #784). `topic_ids` is the
  full desired set on write and every mapped topic on read; the singular
  `topic_id` stays accepted and populated for the currently deployed CMS.
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Chapters
  alias Dbservice.Repo
  alias Dbservice.ResourceTopics
  alias Dbservice.Resources
  alias Dbservice.Topics

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

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  defp map_topics(resource, topics) do
    Enum.each(topics, fn topic ->
      {:ok, _} =
        ResourceTopics.create_resource_topic(%{resource_id: resource.id, topic_id: topic.id})
    end)
  end

  defp mapped_topic_ids(resource_id) do
    resource_id |> ResourceTopics.list_topic_ids_by_resource_id() |> Enum.sort()
  end

  describe "POST /api/resource with topic_ids" do
    test "creates no topic mapping for an empty list", %{conn: conn} do
      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "topic_ids" => []
        })

      body = json_response(conn, 201)
      assert body["topic_ids"] == []
      assert body["topic_id"] == nil
      assert mapped_topic_ids(body["id"]) == []
    end

    test "creates one mapping for a single topic", %{conn: conn} do
      topic = topic_fixture(chapter_fixture())

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "topic_ids" => [topic.id]
        })

      body = json_response(conn, 201)
      assert body["topic_ids"] == [topic.id]
      assert body["topic_id"] == topic.id
    end

    test "creates one mapping per topic for several topics", %{conn: conn} do
      chapter = chapter_fixture()
      first = topic_fixture(chapter)
      second = topic_fixture(chapter)

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "topic_ids" => [first.id, second.id]
        })

      body = json_response(conn, 201)
      assert Enum.sort(body["topic_ids"]) == Enum.sort([first.id, second.id])
      assert mapped_topic_ids(body["id"]) == Enum.sort([first.id, second.id])
    end

    # The whole point of the change: the CMS lists a problem under its chapter but
    # may tag it with topics that live elsewhere.
    test "accepts topics from another chapter", %{conn: conn} do
      own_chapter = chapter_fixture()
      other_chapter = chapter_fixture()
      own_topic = topic_fixture(own_chapter)
      foreign_topic = topic_fixture(other_chapter)

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "chapter_id" => own_chapter.id,
          "topic_ids" => [own_topic.id, foreign_topic.id]
        })

      body = json_response(conn, 201)
      assert Enum.sort(body["topic_ids"]) == Enum.sort([own_topic.id, foreign_topic.id])
      assert body["chapter_id"] == own_chapter.id
    end

    test "still accepts the legacy singular topic_id", %{conn: conn} do
      topic = topic_fixture(chapter_fixture())

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "topic_id" => topic.id
        })

      body = json_response(conn, 201)
      assert body["topic_id"] == topic.id
      assert body["topic_ids"] == [topic.id]
    end
  end

  describe "POST /api/resources/problems/batch with topic_ids" do
    test "maps every listed topic, including one from another chapter", %{conn: conn} do
      own_chapter = chapter_fixture()
      own_topic = topic_fixture(own_chapter)
      foreign_topic = topic_fixture(chapter_fixture())

      conn =
        post(conn, ~p"/api/resources/problems/batch", %{
          "problems" => [
            %{
              "type_params" => %{},
              "chapter_id" => own_chapter.id,
              "topic_ids" => [own_topic.id, foreign_topic.id]
            },
            %{"type_params" => %{}, "topic_ids" => []}
          ]
        })

      body = json_response(conn, 200)
      assert body["failed"] == []
      [first, second] = body["created"]

      assert Enum.sort(first["topic_ids"]) == Enum.sort([own_topic.id, foreign_topic.id])
      assert second["topic_ids"] == []
    end
  end

  describe "PATCH /api/resource/:id with topic_ids" do
    test "adds the topics that are missing and keeps the rest", %{conn: conn} do
      chapter = chapter_fixture()
      kept = topic_fixture(chapter)
      added = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [kept])

      conn =
        patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_ids" => [kept.id, added.id]})

      body = json_response(conn, 200)
      assert Enum.sort(body["topic_ids"]) == Enum.sort([kept.id, added.id])
      assert mapped_topic_ids(problem.id) == Enum.sort([kept.id, added.id])
    end

    # A topic that survives the update must keep its original row, so that nothing
    # downstream sees the mapping disappear and reappear.
    test "leaves the surviving mapping row untouched", %{conn: conn} do
      chapter = chapter_fixture()
      kept = topic_fixture(chapter)
      added = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [kept])

      kept_row =
        ResourceTopics.get_resource_topic_by_resource_id_and_topic_id(problem.id, kept.id)

      patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_ids" => [kept.id, added.id]})

      assert ResourceTopics.get_resource_topic_by_resource_id_and_topic_id(problem.id, kept.id).id ==
               kept_row.id
    end

    test "removes the topics that are no longer listed", %{conn: conn} do
      chapter = chapter_fixture()
      kept = topic_fixture(chapter)
      dropped = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [kept, dropped])

      conn = patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_ids" => [kept.id]})

      assert json_response(conn, 200)["topic_ids"] == [kept.id]
      assert mapped_topic_ids(problem.id) == [kept.id]
    end

    test "clears every topic for an empty list", %{conn: conn} do
      chapter = chapter_fixture()
      problem = problem_fixture()
      map_topics(problem, [topic_fixture(chapter), topic_fixture(chapter)])

      conn = patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_ids" => []})

      body = json_response(conn, 200)
      assert body["topic_ids"] == []
      assert body["topic_id"] == nil
      assert mapped_topic_ids(problem.id) == []
    end

    test "leaves the topics untouched when the key is absent", %{conn: conn} do
      chapter = chapter_fixture()
      topic = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [topic])

      conn = patch(conn, ~p"/api/resource/#{problem.id}", %{"source" => "internal"})

      assert json_response(conn, 200)["topic_ids"] == [topic.id]
      assert mapped_topic_ids(problem.id) == [topic.id]
    end

    test "accepts topics from another chapter without validating them", %{conn: conn} do
      own_chapter = chapter_fixture()
      own_topic = topic_fixture(own_chapter)
      foreign_topic = topic_fixture(chapter_fixture())
      problem = problem_fixture()

      conn =
        patch(conn, ~p"/api/resource/#{problem.id}", %{
          "chapter_id" => own_chapter.id,
          "topic_ids" => [own_topic.id, foreign_topic.id]
        })

      body = json_response(conn, 200)
      assert Enum.sort(body["topic_ids"]) == Enum.sort([own_topic.id, foreign_topic.id])
    end

    # The legacy shape still names one topic, and that topic still has to sit
    # under the chapter the problem is being moved to.
    test "still rejects a legacy topic_id outside the given chapter", %{conn: conn} do
      own_chapter = chapter_fixture()
      foreign_topic = topic_fixture(chapter_fixture())
      problem = problem_fixture()

      conn =
        patch(conn, ~p"/api/resource/#{problem.id}", %{
          "chapter_id" => own_chapter.id,
          "topic_id" => foreign_topic.id
        })

      assert json_response(conn, 422)["errors"]["message"] ==
               "Topic does not belong to the given chapter"
    end

    test "still replaces the whole set from a legacy topic_id", %{conn: conn} do
      chapter = chapter_fixture()
      old_topic = topic_fixture(chapter)
      new_topic = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [old_topic])

      conn = patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_id" => new_topic.id})

      assert json_response(conn, 200)["topic_ids"] == [new_topic.id]
      assert mapped_topic_ids(problem.id) == [new_topic.id]
    end
  end

  describe "PATCH /api/resources/problems/batch with topic_ids" do
    test "applies the full desired set per problem", %{conn: conn} do
      chapter = chapter_fixture()
      first_topic = topic_fixture(chapter)
      foreign_topic = topic_fixture(chapter_fixture())
      first = problem_fixture()
      second = problem_fixture()
      map_topics(second, [first_topic])

      conn =
        patch(conn, ~p"/api/resources/problems/batch", %{
          "problems" => [
            %{"id" => first.id, "topic_ids" => [first_topic.id, foreign_topic.id]},
            %{"id" => second.id, "topic_ids" => []}
          ]
        })

      body = json_response(conn, 200)
      assert body["failed"] == []
      assert mapped_topic_ids(first.id) == Enum.sort([first_topic.id, foreign_topic.id])
      assert mapped_topic_ids(second.id) == []
    end
  end

  describe "POST /api/resources/move" do
    # Moving to another chapter must not silently drop the topic tags: the new CMS
    # simply stops sending a topic when it moves a problem.
    test "leaves the topics alone when neither topic_id nor topic_ids is sent", %{conn: conn} do
      source_chapter = chapter_fixture()
      target_chapter = chapter_fixture()
      topic = topic_fixture(source_chapter)
      problem = problem_fixture()
      map_topics(problem, [topic])

      conn =
        post(conn, ~p"/api/resources/move", %{
          "resource_ids" => [problem.id],
          "chapter_id" => target_chapter.id
        })

      [moved] = json_response(conn, 200)
      assert moved["chapter_id"] == target_chapter.id
      assert moved["topic_ids"] == [topic.id]
      assert mapped_topic_ids(problem.id) == [topic.id]
    end

    test "replaces the topics with topic_ids, cross-chapter topics included", %{conn: conn} do
      target_chapter = chapter_fixture()
      dropped = topic_fixture(chapter_fixture())
      foreign_topic = topic_fixture(chapter_fixture())
      problem = problem_fixture()
      map_topics(problem, [dropped])

      conn =
        post(conn, ~p"/api/resources/move", %{
          "resource_ids" => [problem.id],
          "chapter_id" => target_chapter.id,
          "topic_ids" => [foreign_topic.id]
        })

      [moved] = json_response(conn, 200)
      assert moved["topic_ids"] == [foreign_topic.id]
      assert mapped_topic_ids(problem.id) == [foreign_topic.id]
    end
  end

  describe "response shape" do
    test "topic_id mirrors the first entry of topic_ids", %{conn: conn} do
      chapter = chapter_fixture()
      first = topic_fixture(chapter)
      second = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [first, second])

      body = conn |> get(~p"/api/resource/#{problem.id}") |> json_response(200)

      assert body["topic_ids"] == [first.id, second.id]
      assert body["topic_id"] == first.id
    end

    test "a multi-topic problem is listed once by GET /api/resource", %{conn: conn} do
      chapter = chapter_fixture()
      first = topic_fixture(chapter)
      second = topic_fixture(chapter)

      created =
        conn
        |> post(~p"/api/resource", %{
          "type" => "problem",
          "type_params" => %{},
          "topic_ids" => [first.id, second.id]
        })
        |> json_response(201)

      body = conn |> get(~p"/api/resource", %{"code" => created["code"]}) |> json_response(200)

      assert [listed] = Enum.filter(body, &(&1["id"] == created["id"]))
      assert Enum.sort(listed["topic_ids"]) == Enum.sort([first.id, second.id])
    end
  end

  describe "Resources.normalize_topic_ids/1" do
    test "parses, deduplicates and drops unusable entries" do
      assert Resources.normalize_topic_ids([1, "2", 1, nil, "", "x"]) == [1, 2]
    end

    test "returns an empty list for anything that is not a list" do
      assert Resources.normalize_topic_ids(nil) == []
    end
  end

  describe "repeated updates" do
    test "re-sending the same set is a no-op on the mapping rows", %{conn: conn} do
      chapter = chapter_fixture()
      topic = topic_fixture(chapter)
      problem = problem_fixture()
      map_topics(problem, [topic])

      before_ids = Repo.all(mapping_row_ids(problem.id))
      patch(conn, ~p"/api/resource/#{problem.id}", %{"topic_ids" => [topic.id]})

      assert Repo.all(mapping_row_ids(problem.id)) == before_ids
    end
  end

  import Ecto.Query

  defp mapping_row_ids(resource_id) do
    from(rt in Dbservice.Resources.ResourceTopic,
      where: rt.resource_id == ^resource_id,
      order_by: [asc: rt.id],
      select: rt.id
    )
  end
end
