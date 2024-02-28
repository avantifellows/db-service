defmodule Dbservice.Concepts do
  @moduledoc """
  The Concepts context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Concepts.Concept

  @doc """
  Returns the list of concept.
  ## Examples
      iex> list_concept()
      [%Concept{}, ...]
  """
  def list_concept do
    Repo.all(Concept)
  end

  @doc """
  Gets a single concept.
  Raises `Ecto.NoResultsError` if the concept does not exist.
  ## Examples
      iex> get_concept!(123)
      %Concept{}
      iex> get_concept!(456)
      ** (Ecto.NoResultsError)
  """
  def get_concept!(id), do: Repo.get!(Concept, id)

  @doc """
  Creates a concept.
  ## Examples
      iex> create_concept(%{field: value})
      {:ok, %Concept{}}
      iex> create_concept(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_concept(attrs \\ %{}) do
    %Concept{}
    |> Concept.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a concept.
  ## Examples
      iex> update_concept(concept, %{field: new_value})
      {:ok, %Concept{}}
      iex> update_concept(concept, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_concept(%Concept{} = concept, attrs) do
    concept
    |> Concept.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a concept.
  ## Examples
      iex> delete_concept(concept)
      {:ok, %Concept{}}
      iex> delete_concept(concept)
      {:error, %Ecto.Changeset{}}
  """
  def delete_concept(%Concept{} = concept) do
    Repo.delete(concept)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking concept changes.
  ## Examples
      iex> change_concept(concept)
      %Ecto.Changeset{data: %Concept{}}
  """
  def change_concept(%Concept{} = concept, attrs \\ %{}) do
    Concept.changeset(concept, attrs)
  end
end
