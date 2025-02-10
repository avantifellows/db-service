defmodule Dbservice.ResourceConcepts do
  @moduledoc """
  The ResourceConcepts context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.ResourceConcept

  @doc """
  Returns the list of resource_concept.
  ## Examples
      iex> list_resource_concept()
      [%ResourceConcept{}, ...]
  """
  def list_resource_concept do
    Repo.all(ResourceConcept)
  end

  @doc """
  Gets a single resource_concept.
  Raises `Ecto.NoResultsError` if the resource_concept does not exist.
  ## Examples
      iex> get_resource_concept!(123)
      %ResourceConcept{}
      iex> get_resource_concept!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_concept!(id), do: Repo.get!(ResourceConcept, id)

  @doc """
  Gets a resource-concept based on resource_id and concept_id.
  Raises `Ecto.NoResultsError` if the ResourceConcept does not exist.
  ## Examples
      iex> get_resource_concept_by_resource_concept_id(1, 2)
      %ResourceConcept{}
      iex> get_resource_concept_by_resource_concept_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_resource_concept_by_resource_concept_id(resource_id, concept_id) do
    Repo.get_by(ResourceConcept, resource_id: resource_id, concept_id: concept_id)
  end

  @doc """
  Creates a resource_concept.
  ## Examples
      iex> create_resource_concept(%{field: value})
      {:ok, %ResourceConcept{}}
      iex> create_resource_concept(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_concept(attrs \\ %{}) do
    %ResourceConcept{}
    |> ResourceConcept.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_concept.
  ## Examples
      iex> update_resource_concept(resource_concept, %{field: new_value})
      {:ok, %ResourceConcept{}}
      iex> update_resource_concept(resource_concept, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_concept(%ResourceConcept{} = resource_concept, attrs) do
    resource_concept
    |> ResourceConcept.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_concept.
  ## Examples
      iex> delete_resource_concept(resource)
      {:ok, %ResourceConcept{}}
      iex> delete_resource_concept(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource_concept(%ResourceConcept{} = resource_concept) do
    Repo.delete(resource_concept)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_concept changes.
  ## Examples
      iex> change_resource_concept(resource_concept)
      %Ecto.Changeset{data: %ResourceConcept{}}
  """
  def change_resource(%ResourceConcept{} = resource_concept, attrs \\ %{}) do
    ResourceConcept.changeset(resource_concept, attrs)
  end
end
