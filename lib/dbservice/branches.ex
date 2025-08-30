defmodule Dbservice.Branches do
  @moduledoc """
  The Branches context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Branches.Branch

  @doc """
  Returns the list of branches.
  """
  def list_branch do
    Repo.all(Branch)
  end

  @doc """
  Gets a single branch.
  """
  def get_branch!(id) do
    Repo.get!(Branch, id)
  end

  @doc """
  Gets a branch by branch_id.
  """
  def get_branch_by_branch_id(branch_id) do
    Repo.get_by(Branch, branch_id: branch_id)
  end

  @doc """
  Creates a branch.
  """
  def create_branch(attrs \\ %{}) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a branch.
  """
  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a branch.
  """
  def delete_branch(%Branch{} = branch) do
    Repo.delete(branch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking branch changes.
  """
  def change_branch(%Branch{} = branch, attrs \\ %{}) do
    Branch.changeset(branch, attrs)
  end
end
