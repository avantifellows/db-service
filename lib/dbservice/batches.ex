defmodule Dbservice.Batches do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Batches.Batch

  @doc """
  Returns the list of batch.
  ## Examples
      iex> list_group()
      [%Group{}, ...]
  """
  def list_batch do
    Repo.all(Batch)
  end

  @doc """
  Gets a single batch.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_batch!(123)
      %Group{}
      iex> get_batch!(456)
      ** (Ecto.NoResultsError)
  """
  def get_batch!(id), do: Repo.get!(Batch, id)

  @doc """
  Creates a batch.
  ## Examples
      iex> create_batch(%{field: value})
      {:ok, %Group{}}
      iex> create_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_batch(attrs \\ %{}) do
    %Batch{}
    |> Batch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a batch.
  ## Examples
      iex> update_batch(batch, %{field: new_value})
      {:ok, %Group{}}
      iex> update_batch(batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_batch(%Batch{} = batch, attrs) do
    batch
    |> Batch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a batch.
  ## Examples
      iex> delete_batch(batch)
      {:ok, %GroupUser{}}
      iex> delete_batch(batch)
      {:error, %Ecto.Changeset{}}
  """
  def delete_batch(%Batch{} = batch) do
    Repo.delete(batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  ## Examples
      iex> change_batch(batch)
      %Ecto.Changeset{data: %Groupuser{}}
  """
  def change_batch(%Batch{} = batch, attrs \\ %{}) do
    Batch.changeset(batch, attrs)
  end
end
