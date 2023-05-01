defmodule Dbservice.BatchPrograms do
  @moduledoc """
  The BatchPrograms context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Batches.BatchProgram

  @spec list_batch_program :: any
  @doc """
  Returns the list of batch_program.
  ## Examples
      iex> list_batch_program()
      [%Group{}, ...]
  """
  def list_batch_program do
    Repo.all(BatchProgram)
  end

  @doc """
  Gets a single batch_program.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_batch_program!(123)
      %Group{}
      iex> get_batch_program!(456)
      ** (Ecto.NoResultsError)
  """
  def get_batch_program!(id), do: Repo.get!(BatchProgram, id)

  @doc """
  Creates a batch_program.
  ## Examples
      iex> create_batch_program(%{field: value})
      {:ok, %Group{}}
      iex> create_batch_program(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_batch_program(attrs \\ %{}) do
    %BatchProgram{}
    |> BatchProgram.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a batch_program.
  ## Examples
      iex> update_batch_program(batch_program, %{field: new_value})
      {:ok, %Group{}}
      iex> update_batch_program(batch_program, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_batch_program(%BatchProgram{} = batch_program, attrs) do
    batch_program
    |> BatchProgram.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group_user.
  ## Examples
      iex> delete_batch_program(batch_program)
      {:ok, %GroupUser{}}
      iex> delete_batch_program(batch_program)
      {:error, %Ecto.Changeset{}}
  """
  def delete_batch_program(%BatchProgram{} = batch_program) do
    Repo.delete(batch_program)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  ## Examples
      iex> change_batch_program(batch_program)
      %Ecto.Changeset{data: %Groupuser{}}
  """
  def change_batch_program(%BatchProgram{} = batch_program, attrs \\ %{}) do
    BatchProgram.changeset(batch_program, attrs)
  end
end
