defmodule Dbservice.Grades do
  @moduledoc """
  The Grades context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
  alias Dbservice.Repo

  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group

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
  def get_grade(id), do: Repo.get(Grade, id)

  @doc """
  Gets a grade by number.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_grade_by_number(12)
      %School{}

      iex> get_grade_by_number(12)
      ** (Ecto.NoResultsError)

  """
  def get_grade_by_number(number) do
    Repo.get_by(Grade, number: number)
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
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "grade", child_id: attrs["id"]}])
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

  @doc """
  Gets a grade based on the given parameters.
  Returns `nil` if no grade with the given parameters is found.
  """
  def get_grade_by_params(params) when is_map(params) do
    query = from g in Grade, where: ^Util.build_conditions(params), select: g

    Repo.one(query)
  end
end
