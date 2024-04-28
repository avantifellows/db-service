defmodule Dbservice.Chapters do
  @moduledoc """
  The Chapters context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Chapters.Chapter

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
    %Chapter{}
    |> Chapter.changeset(attrs)
    |> Repo.insert()
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
    chapter
    |> Chapter.changeset(attrs)
    |> Repo.update()
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
