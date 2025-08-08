defmodule Dbservice.ResourceChapters do
  @moduledoc """
  The ResourceChapters context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.ResourceChapter

  @doc """
  Returns the list of resource_chapter.
  ## Examples
      iex> list_resource_chapter()
      [%ResourceChapter{}, ...]
  """
  def list_resource_chapter do
    Repo.all(ResourceChapter)
  end

  @doc """
  Gets a single resource_chapter.
  Raises `Ecto.NoResultsError` if the resource_chapter does not exist.
  ## Examples
      iex> get_resource_chapter!(123)
      %ResourceChapter{}
      iex> get_resource_chapter!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_chapter!(id), do: Repo.get!(ResourceChapter, id)

  @doc """
  Gets a resource-chapter based on resource_id and chapter_id.
  Raises `Ecto.NoResultsError` if the ResourceChapter does not exist.
  ## Examples
      iex> get_resource_chapter_by_resource_id_and_chapter_id(1, 2)
      %ResourceChapter{}
      iex> get_resource_chapter_by_resource_id_and_chapter_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_resource_chapter_by_resource_id_and_chapter_id(resource_id, chapter_id) do
    Repo.get_by(ResourceChapter, resource_id: resource_id, chapter_id: chapter_id)
  end

  @doc """
  Creates a resource_chapter.
  ## Examples
      iex> create_resource_chapter(%{field: value})
      {:ok, %ResourceChapter{}}
      iex> create_resource_chapter(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_chapter(attrs \\ %{}) do
    %ResourceChapter{}
    |> ResourceChapter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_chapter.
  ## Examples
      iex> update_resource_chapter(resource_chapter, %{field: new_value})
      {:ok, %ResourceChapter{}}
      iex> update_resource_chapter(resource_chapter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_chapter(%ResourceChapter{} = resource_chapter, attrs) do
    resource_chapter
    |> ResourceChapter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_chapter.
  ## Examples
      iex> delete_resource_chapter(resource)
      {:ok, %ResourceChapter{}}
      iex> delete_resource_chapter(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource_chapter(%ResourceChapter{} = resource_chapter) do
    Repo.delete(resource_chapter)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_chapter changes.
  ## Examples
      iex> change_resource_chapter(resource_chapter)
      %Ecto.Changeset{data: %ResourceChapter{}}
  """
  def change_resource(%ResourceChapter{} = resource_chapter, attrs \\ %{}) do
    ResourceChapter.changeset(resource_chapter, attrs)
  end
end
