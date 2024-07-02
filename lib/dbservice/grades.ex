defmodule Dbservice.Grades do
  @moduledoc """
  The Grades context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
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

  @doc """
  Gets a grade ID by its number.
  Returns `nil` if no grade with the given number is found.
  """
  def get_grade_id_by_number(grade_number) do
    case Repo.get_by(Grade, number: grade_number) do
      nil -> nil
      grade -> grade.id
    end
  end

  def get_grade_by_params(params) when is_map(params) do
    query = from g in Grade, where: ^Util.build_conditions(params), select: g

    Repo.one(query)
  end

  # defp build_conditions(params) do
  #   Enum.reduce(params, dynamic(true), fn {key, value}, dynamic ->
  #     dynamic([g], field(g, ^key) == ^value and ^dynamic)
  #   end)
  # end
end
