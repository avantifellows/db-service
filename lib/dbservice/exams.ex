defmodule Dbservice.Exams do
  @moduledoc """
  The Exams context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Exams.Exam

  @doc """
  Returns the list of exams.
  ## Examples
      iex> list_exam()
      [%Exam{}, ...]
  """
  def list_exam do
    Repo.all(Exam)
  end

  @doc """
  Gets a single exam.
  Raises `Ecto.NoResultsError` if the Exam does not exist.
  ## Examples
      iex> get_exam!(123)
      %Exam{}
      iex> get_exam!(456)
      ** (Ecto.NoResultsError)
  """
  def get_exam!(id) do
    Repo.get!(Exam, id)
  end

  @doc """
  Gets a Exam by name.
  Raises `Ecto.NoResultsError` if the Exam does not exist.
  ## Examples
      iex> get_exam_by_name(JEE)
      %Exam{}
      iex> get_exam_by_name(123)
      ** (Ecto.NoResultsError)
  """
  def get_exam_by_name(name) do
    Repo.get_by(Exam, name: name)
  end

  @doc """
  Creates a exam.
  ## Examples
      iex> create_exam(%{field: value})
      {:ok, %Exam{}}
      iex> create_exam(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_exam(attrs \\ %{}) do
    %Exam{}
    |> Exam.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a exam.
  ## Examples
      iex> update_exam(exam, %{field: new_value})
      {:ok, %Exam{}}
      iex> update_exam(exam, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_exam(%Exam{} = exam, attrs) do
    exam
    |> Exam.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a exam.
  ## Examples
      iex> delete_exam(exam)
      {:ok, %Exam{}}
      iex> delete_exam(exam)
      {:error, %Ecto.Changeset{}}
  """
  def delete_exam(%Exam{} = exam) do
    Repo.delete(exam)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exam changes.
  ## Examples
      iex> change_exam(exam)
      %Ecto.Changeset{data: %Exam{}}
  """
  def change_exam(%Exam{} = exam, attrs \\ %{}) do
    Exam.changeset(exam, attrs)
  end
end
