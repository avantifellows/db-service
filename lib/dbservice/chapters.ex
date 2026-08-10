defmodule Dbservice.Chapters do
  @moduledoc """
  The Chapters context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Chapters.Chapter
  alias Dbservice.ChapterCurriculums.ChapterCurriculum
  alias Dbservice.ChapterCurriculums
  alias Dbservice.CmsStatuses
  alias Dbservice.Topics.Topic
  alias Dbservice.TopicCurriculums.TopicCurriculum

  @doc """
  Returns the list of chapter.
  ## Examples
      iex> list_chapter()
      [%Chapter{}, ...]
  """
  def list_chapter do
    Repo.all(Chapter)
  end

  @doc """
  Gets a single chapter.
  Raises `Ecto.NoResultsError` if the chapter does not exist.
  ## Examples
      iex> get_chapter!(123)
      %Chapter{}
      iex> get_chapter!(456)
      ** (Ecto.NoResultsError)
  """
  def get_chapter!(id), do: Repo.get!(Chapter, id)

  @doc """
  Counts the topics belonging to each of the given chapters in a single query,
  returning a map of `chapter_id => topic_count`. Chapters with no topics are
  absent from the map (callers should default to 0).

  When `curriculum_id` is given, only topics mapped to that curriculum (via
  `topic_curriculum`) are counted — the count for the same chapter can differ
  per curriculum (see issue #633). When it is nil, every topic under the chapter
  is counted. `count(:distinct)` guards against a topic having more than one
  `topic_curriculum` row for the same curriculum.

  ## Examples
      iex> topic_count_by_chapter_ids([49, 50], 9)
      %{49 => 12, 50 => 7}
  """
  def topic_count_by_chapter_ids([], _curriculum_id), do: %{}

  def topic_count_by_chapter_ids(chapter_ids, curriculum_id) do
    from(t in Topic, as: :topic, where: t.chapter_id in ^chapter_ids)
    |> scope_topic_count_to_curriculum(curriculum_id)
    |> group_by([topic: t], t.chapter_id)
    |> select([topic: t], {t.chapter_id, count(t.id, :distinct)})
    |> Repo.all()
    |> Map.new()
  end

  defp scope_topic_count_to_curriculum(query, nil), do: query

  defp scope_topic_count_to_curriculum(query, curriculum_id) do
    from([topic: t] in query,
      join: tc in TopicCurriculum,
      on: tc.topic_id == t.id and tc.curriculum_id == ^curriculum_id
    )
  end

  @doc """
  Gets a chapter by code.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_chapter_by_code(12)
      %School{}

      iex> get_chapter_by_code(12)
      ** (Ecto.NoResultsError)

  """
  def get_chapter_by_code(code) do
    Repo.get_by(Chapter, code: code)
  end

  @doc """
  Creates a chapter.
  ## Examples
      iex> create_chapter(%{field: value})
      {:ok, %Chapter{}}
      iex> create_chapter(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_chapter(attrs \\ %{}) do
    with {:ok, attrs} <- CmsStatuses.ensure_cms_status_id(attrs) do
      %Chapter{}
      |> Chapter.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Updates a chapter.
  ## Examples
      iex> update_chapter(chapter, %{field: new_value})
      {:ok, %Chapter{}}
      iex> update_chapter(chapter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_chapter(%Chapter{} = chapter, attrs) do
    with {:ok, attrs} <- CmsStatuses.ensure_cms_status_id(attrs) do
      chapter
      |> Chapter.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Creates a chapter and associates it with a curriculum if `curriculum_id` is provided.

  ## Examples

      iex> create_chapter_with_curriculum(%{
      ...>   "title" => "Chapter 1",
      ...>   "curriculum_id" => 1,
      ...>   "priority" => 1,
      ...>   "priority_text" => "High",
      ...>   "weightage" => 10
      ...> })
      {:ok, %Chapter{}}

      iex> create_chapter_with_curriculum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_chapter_with_curriculum(attrs \\ %{}) do
    curriculum_id = Map.get(attrs, "curriculum_id")

    if curriculum_id do
      with {:ok, %Chapter{} = chapter} <- create_chapter(attrs),
           chapter_curriculum_attrs = %{
             "chapter_id" => chapter.id,
             "curriculum_id" => curriculum_id,
             "priority" => Map.get(attrs, "priority"),
             "priority_text" => Map.get(attrs, "priority_text"),
             "weightage" => Map.get(attrs, "weightage")
           },
           {:ok, %ChapterCurriculum{}} <-
             ChapterCurriculums.create_chapter_curriculum(chapter_curriculum_attrs) do
        {:ok, chapter}
      end
    else
      create_chapter(attrs)
    end
  end

  @doc """
  Updates a chapter and its associated curriculum data if `curriculum_id` is provided.

  ## Examples

      iex> update_chapter_with_curriculum(chapter, %{
      ...>   "title" => "Updated Title",
      ...>   "curriculum_id" => 1,
      ...>   "priority" => 2,
      ...>   "priority_text" => "Medium",
      ...>   "weightage" => 15
      ...> })
      {:ok, %Chapter{}}

      iex> update_chapter_with_curriculum(chapter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_chapter_with_curriculum(chapter, attrs \\ %{}) do
    curriculum_id = Map.get(attrs, "curriculum_id")

    if curriculum_id do
      with {:ok, %Chapter{} = updated_chapter} <- update_chapter(chapter, attrs) do
        update_chapter_curriculum_mapping(updated_chapter, curriculum_id, attrs)
        {:ok, updated_chapter}
      end
    else
      update_chapter(chapter, attrs)
    end
  end

  defp update_chapter_curriculum_mapping(chapter, curriculum_id, attrs) do
    chapter_curriculum_attrs = %{
      "chapter_id" => chapter.id,
      "curriculum_id" => curriculum_id,
      "priority" => Map.get(attrs, "priority"),
      "priority_text" => Map.get(attrs, "priority_text"),
      "weightage" => Map.get(attrs, "weightage")
    }

    case ChapterCurriculums.get_chapter_curriculum_by_chapter_id_and_curriculum_id(
           chapter.id,
           curriculum_id
         ) do
      nil ->
        ChapterCurriculums.create_chapter_curriculum(chapter_curriculum_attrs)

      existing_chapter_curriculum ->
        ChapterCurriculums.update_chapter_curriculum(
          existing_chapter_curriculum,
          chapter_curriculum_attrs
        )
    end
  end

  @doc """
  Deletes a chapter.
  ## Examples
      iex> delete_chapter(chapter)
      {:ok, %Chapter{}}
      iex> delete_chapter(chapter)
      {:error, %Ecto.Changeset{}}
  """
  def delete_chapter(%Chapter{} = chapter) do
    Repo.delete(chapter)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chapter changes.
  ## Examples
      iex> change_chapter(chapter)
      %Ecto.Changeset{data: %Chapter{}}
  """
  def change_chapter(%Chapter{} = chapter, attrs \\ %{}) do
    Chapter.changeset(chapter, attrs)
  end
end
