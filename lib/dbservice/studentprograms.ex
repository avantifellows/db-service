defmodule Dbservice.StudentPrograms do
  @moduledoc """
  The StudentPrograms context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.StudentPrograms.StudentProgram

  @doc """
  Returns the list of student_program.
  
  ## Examples
  
      iex> list_student_program()
      [%student_program{}, ...]
  
  """
  def list_studentprogram do
    Repo.all(StudentProgram)
  end

  @doc """
  Gets a single student_program.
  
  Raises `Ecto.NoResultsError` if the student_program does not exist.
  
  ## Examples
  
      iex> get_student_program!(123)
      %student_program{}
  
      iex> get_student_program!(456)
      ** (Ecto.NoResultsError)
  
  """
  def get_studentprogram!(id), do: Repo.get!(StudentProgram, id)

  @doc """
  Creates a student_program.
  
  ## Examples
  
      iex> create_student_program(%{field: value})
      {:ok, %student_program{}}
  
      iex> create_student_program(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  
  """
  def create_studentprogram(attrs \\ %{}) do
    %StudentProgram{}
    |> StudentProgram.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a student_program.
  
  ## Examples
  
      iex> update_student_program(student_program, %{field: new_value})
      {:ok, %student_program{}}
  
      iex> update_student_program(student_program, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  
  """
  def update_studentprogram(%StudentProgram{} = student_program, attrs) do
    student_program
    |> StudentProgram.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a student_program.
  
  ## Examples
  
      iex> delete_student_program(student_program)
      {:ok, %student_program{}}
  
      iex> delete_student_program(student_program)
      {:error, %Ecto.Changeset{}}
  
  """
  def delete_studentprogram(%StudentProgram{} = student_program) do
    Repo.delete(student_program)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking student_program changes.
  
  ## Examples
  
      iex> change_student_program(student_program)
      %Ecto.Changeset{data: %student_program{}}
  
  """
  def change_studentProgram(%StudentProgram{} = student_program, attrs \\ %{}) do
    StudentProgram.changeset(student_program, attrs)
  end
end
