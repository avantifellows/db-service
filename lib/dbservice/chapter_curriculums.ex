defmodule Dbservice.ChapterCurriculums do
  @moduledoc """
  The ChapterCurriculums context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.ChapterCurriculums.ChapterCurriculum

  @doc """
  Returns the list of chapter_curriculum.
  ## Examples
      iex> list_chapter_curriculum()
      [%ChapterCurriculum{}, ...]
  """
  def list_chapter_curriculum do
    Repo.all(ChapterCurriculum)
  end

  @doc """
  Gets a single chapter_curriculum.
  Raises `Ecto.NoResultsError` if the chapter_curriculum does not exist.
  ## Examples
      iex> get_chapter_curriculum!(123)
      %ChapterCurriculum{}
      iex> get_chapter_curriculum!(456)
      ** (Ecto.NoResultsError)
  """
  def get_chapter_curriculum!(id), do: Repo.get!(ChapterCurriculum, id)

  @doc """
  Gets a chapter-curriculum based on chapter_id and curriculum_id.
  Raises `Ecto.NoResultsError` if the ChapterCurriculum does not exist.
  ## Examples
      iex> get_chapter_curriculum_by_chapter_id_and_curriculum_id(1, 2)
      %ChapterCurriculum{}
      iex> get_chapter_curriculum_by_chapter_id_and_curriculum_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_chapter_curriculum_by_chapter_id_and_curriculum_id(chapter_id, curriculum_id) do
    Repo.get_by(ChapterCurriculum, chapter_id: chapter_id, curriculum_id: curriculum_id)
  end

  @doc """
  Creates a chapter_curriculum.
  ## Examples
      iex> create_chapter_curriculum(%{field: value})
      {:ok, %ChapterCurriculum{}}
      iex> create_chapter_curriculum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_chapter_curriculum(attrs \\ %{}) do
    %ChapterCurriculum{}
    |> ChapterCurriculum.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a chapter_curriculum.
  ## Examples
      iex> update_chapter_curriculum(chapter_curriculum, %{field: new_value})
      {:ok, %ChapterCurriculum{}}
      iex> update_chapter_curriculum(chapter_curriculum, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_chapter_curriculum(%ChapterCurriculum{} = chapter_curriculum, attrs) do
    chapter_curriculum
    |> ChapterCurriculum.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a chapter_curriculum.
  ## Examples
      iex> delete_chapter_curriculum(chapter)
      {:ok, %ChapterCurriculum{}}
      iex> delete_chapter_curriculum(chapter)
      {:error, %Ecto.Changeset{}}
  """
  def delete_chapter_curriculum(%ChapterCurriculum{} = chapter_curriculum) do
    Repo.delete(chapter_curriculum)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chapter_curriculum changes.
  ## Examples
      iex> change_chapter_curriculum(chapter_curriculum)
      %Ecto.Changeset{data: %ChapterCurriculum{}}
  """
  def change_chapter(%ChapterCurriculum{} = chapter_curriculum, attrs \\ %{}) do
    ChapterCurriculum.changeset(chapter_curriculum, attrs)
  end
end
