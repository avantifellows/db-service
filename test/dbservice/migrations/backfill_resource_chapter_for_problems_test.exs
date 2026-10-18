defmodule Dbservice.Migrations.BackfillResourceChapterForProblemsTest do
  @moduledoc """
  The backfill behind issue #785: problems listed by chapter need a
  `resource_chapter` row, and a few only ever got a topic. Exercises the
  migration's own SQL (not a copy of it) against fixtures, since the migration
  itself has already run on the test database.
  """
  use Dbservice.DataCase

  import Ecto.Query

  alias Dbservice.Chapters
  alias Dbservice.Repo
  alias Dbservice.ResourceChapters
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.ResourceTopics
  alias Dbservice.Resources
  alias Dbservice.Topics

  Code.require_file(
    "priv/repo/migrations/20261018120000_backfill_resource_chapter_for_problems.exs"
  )

  @migration Dbservice.Repo.Migrations.BackfillResourceChapterForProblems

  defp run_backfill, do: Repo.query!(@migration.backfill_sql())

  defp chapter_fixture do
    {:ok, chapter} =
      Chapters.create_chapter(%{"code" => "CH-#{System.unique_integer([:positive])}"})

    chapter
  end

  defp topic_fixture(chapter) do
    {:ok, topic} =
      Topics.create_topic(%{
        "code" => "TOP-#{System.unique_integer([:positive])}",
        "chapter_id" => chapter && chapter.id
      })

    topic
  end

  defp problem_fixture(opts \\ []) do
    {:ok, resource} =
      Resources.create_resource(%{
        "type" => Keyword.get(opts, :type, "problem"),
        "type_params" => %{}
      })

    Enum.each(Keyword.get(opts, :topics, []), fn topic ->
      {:ok, _} =
        ResourceTopics.create_resource_topic(%{resource_id: resource.id, topic_id: topic.id})
    end)

    Enum.each(Keyword.get(opts, :chapters, []), fn chapter ->
      {:ok, _} =
        ResourceChapters.create_resource_chapter(%{
          resource_id: resource.id,
          chapter_id: chapter.id
        })
    end)

    resource
  end

  defp chapter_ids(resource) do
    from(rc in ResourceChapter,
      where: rc.resource_id == ^resource.id,
      order_by: [asc: rc.chapter_id],
      select: rc.chapter_id
    )
    |> Repo.all()
  end

  test "a problem with a topic and no chapter gets the topic's chapter" do
    chapter = chapter_fixture()
    problem = problem_fixture(topics: [topic_fixture(chapter)])

    run_backfill()

    assert chapter_ids(problem) == [chapter.id]
  end

  test "several topics pointing at the same chapter insert exactly one row" do
    chapter = chapter_fixture()
    problem = problem_fixture(topics: [topic_fixture(chapter), topic_fixture(chapter)])

    run_backfill()

    assert chapter_ids(problem) == [chapter.id]
  end

  test "a problem that already has a chapter is left untouched" do
    existing_chapter = chapter_fixture()
    other_chapter = chapter_fixture()

    problem =
      problem_fixture(chapters: [existing_chapter], topics: [topic_fixture(other_chapter)])

    run_backfill()

    assert chapter_ids(problem) == [existing_chapter.id]
  end

  test "a problem whose topics span several chapters is skipped" do
    problem =
      problem_fixture(
        topics: [topic_fixture(chapter_fixture()), topic_fixture(chapter_fixture())]
      )

    run_backfill()

    assert chapter_ids(problem) == []
  end

  test "a problem with neither chapter nor topic is skipped" do
    problem = problem_fixture()

    run_backfill()

    assert chapter_ids(problem) == []
  end

  test "a topic with no chapter of its own cannot supply one" do
    problem = problem_fixture(topics: [topic_fixture(nil)])

    run_backfill()

    assert chapter_ids(problem) == []
  end

  test "non-problem resources are not touched" do
    chapter = chapter_fixture()
    test_resource = problem_fixture(type: "test", topics: [topic_fixture(chapter)])

    run_backfill()

    assert chapter_ids(test_resource) == []
  end

  test "re-running it inserts nothing the second time" do
    chapter = chapter_fixture()
    problem = problem_fixture(topics: [topic_fixture(chapter)])

    run_backfill()
    %Postgrex.Result{num_rows: second_run} = run_backfill()

    assert second_run == 0
    assert chapter_ids(problem) == [chapter.id]
  end

  test "the unresolvable-problem report runs and reports nothing fatal" do
    problem_fixture(topics: [topic_fixture(chapter_fixture()), topic_fixture(chapter_fixture())])

    assert %Postgrex.Result{} = Repo.query!(@migration.report_unresolvable_sql())
  end
end
