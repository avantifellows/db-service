defmodule Dbservice.ResourceCurriculums do
  @moduledoc """
  The ResourceCurriculums context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.ResourceCurriculum

  @doc """
  Returns the list of resource_curriculum.
  ## Examples
      iex> list_resource_curriculum()
      [%ResourceCurriculum{}, ...]
  """
  def list_resource_curriculum do
    Repo.all(ResourceCurriculum)
  end

  @doc """
  Gets a single resource_curriculum.
  Raises `Ecto.NoResultsError` if the resource_curriculum does not exist.
  ## Examples
      iex> get_resource_curriculum!(123)
      %ResourceCurriculum{}
      iex> get_resource_curriculum!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_curriculum!(id), do: Repo.get!(ResourceCurriculum, id)

  @doc """
  Gets a resource-curriculum based on resource_id and curriculum_id.
  Raises `Ecto.NoResultsError` if the ResourceCurriculum does not exist.
  ## Examples
      iex> get_resource_curriculum_by_resource_id_and_curriculum_id(1, 2)
      %ResourceCurriculum{}
      iex> get_resource_curriculum_by_resource_id_and_curriculum_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_resource_curriculum_by_resource_id_and_curriculum_id(resource_id, curriculum_id) do
    Repo.get_by(ResourceCurriculum, resource_id: resource_id, curriculum_id: curriculum_id)
  end

  @doc """
  Creates a resource_curriculum.
  ## Examples
      iex> create_resource_curriculum(%{field: value})
      {:ok, %ResourceCurriculum{}}
      iex> create_resource_curriculum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_curriculum(attrs \\ %{}) do
    %ResourceCurriculum{}
    |> ResourceCurriculum.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_curriculum.
  ## Examples
      iex> update_resource_curriculum(resource_curriculum, %{field: new_value})
      {:ok, %ResourceCurriculum{}}
      iex> update_resource_curriculum(resource_curriculum, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_curriculum(%ResourceCurriculum{} = resource_curriculum, attrs) do
    resource_curriculum
    |> ResourceCurriculum.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_curriculum.
  ## Examples
      iex> delete_resource_curriculum(resource)
      {:ok, %ResourceCurriculum{}}
      iex> delete_resource_curriculum(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource_curriculum(%ResourceCurriculum{} = resource_curriculum) do
    Repo.delete(resource_curriculum)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_curriculum changes.
  ## Examples
      iex> change_resource_curriculum(resource_curriculum)
      %Ecto.Changeset{data: %ResourceCurriculum{}}
  """
  def change_resource(%ResourceCurriculum{} = resource_curriculum, attrs \\ %{}) do
    ResourceCurriculum.changeset(resource_curriculum, attrs)
  end
end
