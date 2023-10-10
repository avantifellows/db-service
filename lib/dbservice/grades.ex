defmodule Dbservice.Grades do
  @moduledoc """
  The Grades context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Grades.Grade

  @doc """
  Returns the list of grade.
  ## Examples
      iex> list_grade()
      [%Grade{}, ...]
  """
  def list_grade do
    Repo.all(Grade)
  end

  @doc """
  Gets a single grade.
  Raises `Ecto.NoResultsError` if the grade does not exist.
  ## Examples
      iex> get_grade!(123)
      %Grade{}
      iex> get_grade!(456)
      ** (Ecto.NoResultsError)
  """
  def get_grade!(id), do: Repo.get!(Grade, id)

  @doc """
  Creates one or more grades.

  ## Examples
      iex> create_grades([%{field: value}])
      {:ok, [%Grade{}]}
      iex> create_grades([%{field: value}, %{field: value}])
      {:ok, [%Grade{}, %Grade{}]}
      iex> create_grades([%{field: bad_value}])
      {:error, %{}}
  """

  def create_grades([]), do: {:error, %{}}

  def create_grades(params) do
    Enum.reduce(params, {:ok, []}, fn attrs, {:ok, grades} ->
      case create_grade(attrs) do
        {:ok, grade} ->
          {:ok, [grade | grades]}

        {:error, _changeset} ->
          {:error, %{}}
      end
    end)
  end

  @doc """
  Creates a grade.
  ## Examples
      iex> create_grade(%{field: value})
      {:ok, %Grade{}}
      iex> create_grade(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_grade(attrs \\ %{}) do
    %Grade{}
    |> Grade.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a grade.
  ## Examples
      iex> update_grade(grade, %{field: new_value})
      {:ok, %Grade{}}
      iex> update_grade(grade, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_grade(%Grade{} = grade, attrs) do
    grade
    |> Grade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grade.
  ## Examples
      iex> delete_grade(grade)
      {:ok, %Grade{}}
      iex> delete_grade(grade)
      {:error, %Ecto.Changeset{}}
  """
  def delete_grade(%Grade{} = grade) do
    Repo.delete(grade)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking grade changes.
  ## Examples
      iex> change_grade(grade)
      %Ecto.Changeset{data: %Grade{}}
  """
  def change_grade(%Grade{} = grade, attrs \\ %{}) do
    Grade.changeset(grade, attrs)
  end
end
