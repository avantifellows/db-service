defmodule Dbservice.Cutoffs do
  @moduledoc """
  The Cutoffs context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Cutoffs.Cutoff

  @doc """
  Returns the list of cutoffs.

  ## Examples

      iex> list_cutoffs()
      [%Cutoff{}, ...]
  """
  def list_cutoffs do
    Repo.all(Cutoff)
  end

  @doc """
  Gets a single cutoff.

  Raises `Ecto.NoResultsError` if the cutoff does not exist.

  ## Examples

      iex> get_cutoff!(123)
      %Cutoff{}

      iex> get_cutoff!(456)
      ** (Ecto.NoResultsError)
  """
  def get_cutoff!(id) do
    Repo.get!(Cutoff, id)
  end

  @doc """
  Gets cutoffs by exam_occurrence_id.

  ## Examples

      iex> get_cutoffs_by_exam_occurrence_id(1)
      [%Cutoff{}, ...]

      iex> get_cutoffs_by_exam_occurrence_id(999)
      []
  """
  def get_cutoffs_by_exam_occurrence_id(exam_occurrence_id) do
    Cutoff
    |> where([c], c.exam_occurrence_id == ^exam_occurrence_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by college_id.

  ## Examples

      iex> get_cutoffs_by_college_id(1)
      [%Cutoff{}, ...]

      iex> get_cutoffs_by_college_id(999)
      []
  """
  def get_cutoffs_by_college_id(college_id) do
    Cutoff
    |> where([c], c.college_id == ^college_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by branch_id.

  ## Examples

      iex> get_cutoffs_by_branch_id(1)
      [%Cutoff{}, ...]

      iex> get_cutoffs_by_branch_id(999)
      []
  """
  def get_cutoffs_by_branch_id(branch_id) do
    Cutoff
    |> where([c], c.branch_id == ^branch_id)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs by category.

  ## Examples

      iex> get_cutoffs_by_category("General")
      [%Cutoff{}, ...]

      iex> get_cutoffs_by_category("Unknown")
      []
  """
  def get_cutoffs_by_category(category) do
    Cutoff
    |> where([c], c.category == ^category)
    |> Repo.all()
  end

  @doc """
  Gets cutoffs with all associations preloaded.

  Raises `Ecto.NoResultsError` if the cutoff does not exist.

  ## Examples

      iex> get_cutoff_with_associations!(123)
      %Cutoff{exam_occurrence: %ExamOccurrence{}, college: %College{}, branch: %Branch{}}

      iex> get_cutoff_with_associations!(456)
      ** (Ecto.NoResultsError)
  """
  def get_cutoff_with_associations!(id) do
    Cutoff
    |> Repo.get!(id)
    |> Repo.preload([:exam_occurrence, :college, :branch])
  end

  @doc """
  Creates a cutoff.

  ## Examples

      iex> create_cutoff(%{field: value})
      {:ok, %Cutoff{}}

      iex> create_cutoff(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_cutoff(attrs \\ %{}) do
    %Cutoff{}
    |> Cutoff.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cutoff.

  ## Examples

      iex> update_cutoff(cutoff, %{field: new_value})
      {:ok, %Cutoff{}}

      iex> update_cutoff(cutoff, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_cutoff(%Cutoff{} = cutoff, attrs) do
    cutoff
    |> Cutoff.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cutoff.

  ## Examples

      iex> delete_cutoff(cutoff)
      {:ok, %Cutoff{}}

      iex> delete_cutoff(cutoff)
      {:error, %Ecto.Changeset{}}
  """
  def delete_cutoff(%Cutoff{} = cutoff) do
    Repo.delete(cutoff)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cutoff changes.

  ## Examples

      iex> change_cutoff(cutoff)
      %Ecto.Changeset{data: %Cutoff{}}
  """
  def change_cutoff(%Cutoff{} = cutoff, attrs \\ %{}) do
    Cutoff.changeset(cutoff, attrs)
  end
end
