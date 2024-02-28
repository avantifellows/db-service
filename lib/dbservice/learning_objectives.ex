defmodule Dbservice.LearningObjectives do
  @moduledoc """
  The LearningObjectives context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.LearningObjectives.LearningObjective

  @doc """
  Returns the list of learning_objective.
  ## Examples
      iex> list_learning_objective()
      [%LearningObjective{}, ...]
  """
  def list_learning_objective do
    Repo.all(LearningObjective)
  end

  @doc """
  Gets a single learning_objective.
  Raises `Ecto.NoResultsError` if the learning_objective does not exist.
  ## Examples
      iex> get_learning_objective!(123)
      %LearningObjective{}
      iex> get_learning_objective!(456)
      ** (Ecto.NoResultsError)
  """
  def get_learning_objective!(id), do: Repo.get!(LearningObjective, id)

  @doc """
  Creates a learning_objective.
  ## Examples
      iex> create_learning_objective(%{field: value})
      {:ok, %LearningObjective{}}
      iex> create_learning_objective(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_learning_objective(attrs \\ %{}) do
    %LearningObjective{}
    |> LearningObjective.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a learning_objective.
  ## Examples
      iex> update_learning_objective(learning_objective, %{field: new_value})
      {:ok, %LearningObjective{}}
      iex> update_learning_objective(learning_objective, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_learning_objective(%LearningObjective{} = learning_objective, attrs) do
    learning_objective
    |> LearningObjective.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a learning_objective.
  ## Examples
      iex> delete_learning_objective(learning_objective)
      {:ok, %LearningObjective{}}
      iex> delete_learning_objective(learning_objective)
      {:error, %Ecto.Changeset{}}
  """
  def delete_learning_objective(%LearningObjective{} = learning_objective) do
    Repo.delete(learning_objective)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking learning_objective changes.
  ## Examples
      iex> change_learning_objective(learning_objective)
      %Ecto.Changeset{data: %LearningObjective{}}
  """
  def change_learning_objective(%LearningObjective{} = learning_objective, attrs \\ %{}) do
    LearningObjective.changeset(learning_objective, attrs)
  end
end
