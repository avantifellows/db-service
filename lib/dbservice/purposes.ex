defmodule Dbservice.Purposes do
  @moduledoc """
  The Purposes context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Purposes.Purpose

  @doc """
  Returns the list of purpose.
  ## Examples
      iex> list_purpose()
      [%Purpose{}, ...]
  """
  def list_purpose do
    Repo.all(Purpose)
  end

  @doc """
  Gets a single purpose.
  Raises `Ecto.NoResultsError` if the purpose does not exist.
  ## Examples
      iex> get_purpose!(123)
      %Purpose{}
      iex> get_purpose!(456)
      ** (Ecto.NoResultsError)
  """
  def get_purpose!(id), do: Repo.get!(Purpose, id)

  @doc """
  Creates a purpose.
  ## Examples
      iex> create_purpose(%{field: value})
      {:ok, %Purpose{}}
      iex> create_purpose(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_purpose(attrs \\ %{}) do
    %Purpose{}
    |> Purpose.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a purpose.
  ## Examples
      iex> update_purpose(purpose, %{field: new_value})
      {:ok, %Purpose{}}
      iex> update_purpose(purpose, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_purpose(%Purpose{} = purpose, attrs) do
    purpose
    |> Purpose.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a purpose.
  ## Examples
      iex> delete_purpose(purpose)
      {:ok, %Purpose{}}
      iex> delete_purpose(purpose)
      {:error, %Ecto.Changeset{}}
  """
  def delete_purpose(%Purpose{} = purpose) do
    Repo.delete(purpose)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking purpose changes.
  ## Examples
      iex> change_purpose(purpose)
      %Ecto.Changeset{data: %Purpose{}}
  """
  def change_purpose(%Purpose{} = purpose, attrs \\ %{}) do
    Purpose.changeset(purpose, attrs)
  end
end
