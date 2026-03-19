defmodule Dbservice.Batches do
  @moduledoc """
  The Batches context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of batch.
  ## Examples
      iex> list_batch()
      [%Batch{}, ...]
  """
  def list_batch do
    Repo.all(Batch)
  end

  @doc """
  Gets a single batch.
  Raises `Ecto.NoResultsError` if the batch does not exist.
  ## Examples
      iex> get_batch!(123)
      %Batch{}
      iex> get_batch!(456)
      ** (Ecto.NoResultsError)
  """
  def get_batch!(id), do: Repo.get!(Batch, id)

  @doc """
  Gets a Batch by batch ID.
  Raises `Ecto.NoResultsError` if the Batch does not exist.
  ## Examples
      iex> get_batch_by_batch_id(1234)
      %Batch{}
      iex> get_batch_by_batch_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_batch_by_batch_id(batch_id) do
    Repo.get_by(Batch, batch_id: batch_id)
  end

  @doc """
  Creates a batch.
  ## Examples
      iex> create_batch(%{field: value})
      {:ok, %Batch{}}
      iex> create_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_batch(attrs \\ %{}) do
    %Batch{}
    |> Batch.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "batch", child_id: attrs["id"]}])
    |> Repo.insert()
  end

  @doc """
  Gets a batch by batch_id. Returns nil if not found.
  """
  def get_batch_by_batch_id_nil(batch_id) when is_binary(batch_id) do
    batch_id = String.trim(batch_id)
    if batch_id == "", do: nil, else: Repo.get_by(Batch, batch_id: batch_id)
  end

  def get_batch_by_batch_id_nil(_), do: nil

  @doc """
  Creates a batch and its group row (child_id = batch.id, type \"batch\").
  Used by data import.
  """
  def create_batch_from_import(attrs) when is_map(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:batch, Batch.changeset(%Batch{}, attrs))
    |> Ecto.Multi.insert(:group, fn %{batch: b} ->
      Group.changeset(%Group{}, %{type: "batch", child_id: b.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{batch: b}} -> {:ok, b}
      {:error, :batch, changeset, _} -> {:error, changeset}
      {:error, :group, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates a batch.
  ## Examples
      iex> update_batch(batch, %{field: new_value})
      {:ok, %Batch{}}
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
      {:ok, %Batch{}}
      iex> delete_batch(batch)
      {:error, %Ecto.Changeset{}}
  """
  def delete_batch(%Batch{} = batch) do
    Repo.delete(batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking batch changes.
  ## Examples
      iex> change_batch(batch)
      %Ecto.Changeset{data: %Batch{}}
  """
  def change_batch(%Batch{} = batch, attrs \\ %{}) do
    Batch.changeset(batch, attrs)
  end
end
