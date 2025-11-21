defmodule Dbservice.Branches do
  @moduledoc """
  The Branches context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Branches.Branch

  @doc """
  Returns the list of branches.

  ## Examples

      iex> list_branch()
      [%Branch{}, ...]
  """
  def list_branch do
    Repo.all(Branch)
  end

  @doc """
  Gets a single branch.

  Raises `Ecto.NoResultsError` if the branch does not exist.

  ## Examples

      iex> get_branch!(123)
      %Branch{}

      iex> get_branch!(456)
      ** (Ecto.NoResultsError)
  """
  def get_branch!(id) do
    Repo.get!(Branch, id)
  end

  @doc """
  Gets a branch by branch_id.

  ## Examples

      iex> get_branch_by_branch_id(1234)
      %Branch{}

      iex> get_branch_by_branch_id(9999)
      nil
  """
  def get_branch_by_branch_id(branch_id) do
    Repo.get_by(Branch, branch_id: branch_id)
  end

  @doc """
  Creates a branch.

  ## Examples

      iex> create_branch(%{field: value})
      {:ok, %Branch{}}

      iex> create_branch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_branch(attrs \\ %{}) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a branch.

  ## Examples

      iex> update_branch(branch, %{field: new_value})
      {:ok, %Branch{}}

      iex> update_branch(branch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a branch.

  ## Examples

      iex> delete_branch(branch)
      {:ok, %Branch{}}

      iex> delete_branch(branch)
      {:error, %Ecto.Changeset{}}
  """
  def delete_branch(%Branch{} = branch) do
    Repo.delete(branch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking branch changes.

  ## Examples

      iex> change_branch(branch)
      %Ecto.Changeset{data: %Branch{}}
  """
  def change_branch(%Branch{} = branch, attrs \\ %{}) do
    Branch.changeset(branch, attrs)
  end
end
