defmodule Dbservice.Cutoffs do
  @moduledoc """
  The Cutoffs context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Cutoffs.Cutoff

  @doc """
  Returns the list of cutoffs.
  """
  def list_cutoffs do
    Repo.all(Cutoff)
  end

  @doc """
  Gets a single cutoff.
  """
  def get_cutoff!(id) do
    Repo.get!(Cutoff, id)
  end

  @doc """
  Gets cutoffs by exam_occurrence_id.
  """
  def get_cutoffs_by_exam_occurrence_id(exam_occurrence_id) do
    Cutoff
    |> where([c], c.exam_occurrence_id == ^exam_occurrence_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by college_id.
  """
  def get_cutoffs_by_college_id(college_id) do
    Cutoff
    |> where([c], c.college_id == ^college_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by branch_id.
  """
  def get_cutoffs_by_branch_id(branch_id) do
    Cutoff
    |> where([c], c.branch_id == ^branch_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by category.
  """
  def get_cutoffs_by_category(category) do
    Cutoff
    |> where([c], c.category == ^category)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs with all associations preloaded.
  """
  def get_cutoff_with_associations!(id) do
    Cutoff
    |> Repo.get!(id)
    |> Repo.preload([:exam_occurrence, :college, :branch])
  end

  @doc """
  Creates a cutoff.
  """
  def create_cutoff(attrs \\ %{}) do
    %Cutoff{}
    |> Cutoff.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cutoff.
  """
  def update_cutoff(%Cutoff{} = cutoff, attrs) do
    cutoff
    |> Cutoff.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cutoff.
  """
  def delete_cutoff(%Cutoff{} = cutoff) do
    Repo.delete(cutoff)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cutoff changes.
  """
  def change_cutoff(%Cutoff{} = cutoff, attrs \\ %{}) do
    Cutoff.changeset(cutoff, attrs)
  end
end
