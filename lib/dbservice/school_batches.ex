defmodule Dbservice.SchoolBatches do
  @moduledoc """
  The SchoolBatches context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.SchoolBatches.SchoolBatch

  @doc """
  Returns the list of school_batch.

  ## Examples

      iex> list_school_batch()
      [%SchoolBatch{}, ...]

  """
  def list_school_batch do
    Repo.all(SchoolBatch)
  end

  @doc """
  Gets a single school_batch.

  Raises `Ecto.NoResultsError` if the SchoolBatch does not exist.

  ## Examples

      iex> get_school_batch!(123)
      %SchoolBatch{}

      iex> get_school_batch!(456)
      ** (Ecto.NoResultsError)

  """
  def get_school_batch!(id), do: Repo.get!(SchoolBatch, id)

  @doc """
  Gets a school_batch based on school_id and batch_id.
  Raises `Ecto.NoResultsError` if the SchoolBatch does not exist.
  ## Examples
      iex> get_school_batch_by_school_id_and_batch_id(1, 2)
      %SchoolBatch{}
      iex> get_school_batch_by_school_id_and_batch_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_school_batch_by_school_id_and_batch_id(school_id, batch_id) do
    Repo.get_by(SchoolBatch, school_id: school_id, batch_id: batch_id)
  end

  @doc """
  Gets a school-batch by batch ID.
  Raises `Ecto.NoResultsError` if the SchoolBatch does not exist.
  ## Examples
      iex> get_school_batch_by_batch_id(1234)
      %SchoolBatch{}
      iex> get_school_batch_by_batch_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_school_batch_by_batch_id(batch_id) do
    from(g in SchoolBatch, where: g.batch_id == ^batch_id)
    |> Repo.all()
  end

  @doc """
  Creates a school_batch.

  ## Examples

      iex> create_school_batch(%{field: value})
      {:ok, %SchoolBatch{}}

      iex> create_school_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_school_batch(attrs \\ %{}) do
    %SchoolBatch{}
    |> SchoolBatch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a school_batch.

  ## Examples

      iex> update_school_batch(school_batch, %{field: new_value})
      {:ok, %SchoolBatch{}}

      iex> update_school_batch(school_batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_school_batch(%SchoolBatch{} = school_batch, attrs) do
    school_batch
    |> SchoolBatch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a school_batch.

  ## Examples

      iex> delete_school_batch(school_batch)
      {:ok, %SchoolBatch{}}

      iex> delete_school_batch(school_batch)
      {:error, %Ecto.Changeset{}}

  """
  def delete_school_batch(%SchoolBatch{} = school_batch) do
    Repo.delete(school_batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking school_batch changes.

  ## Examples

      iex> change_school_batch(school_batch)
      %Ecto.Changeset{data: %SchoolBatch{}}

  """
  def change_school_batch(%SchoolBatch{} = school_batch, attrs \\ %{}) do
    SchoolBatch.changeset(school_batch, attrs)
  end
end
