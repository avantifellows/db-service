defmodule Dbservice.Programs do
  @moduledoc """
  The Programs context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Programs.Program

  @doc """
  Returns the list of program.
  
  ## Examples
  
      iex> list_program()
      [%program{}, ...]
  
  """
  def list_program do
    Repo.all(Program)
  end

  @doc """
  Gets a single program.
  
  Raises `Ecto.NoResultsError` if the Program does not exist.
  
  ## Examples
  
      iex> get_program!(123)
      %program{}
  
      iex> get_program!(456)
      ** (Ecto.NoResultsError)
  
  """
  def get_program!(id), do: Repo.get!(Program, id)

  @doc """
  Creates a program.
  
  ## Examples
  
      iex> create_program(%{field: value})
      {:ok, %program{}}
  
      iex> create_program(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  
  """
  def create_program(attrs \\ %{}) do
    %Program{}
    |> Program.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a program.
  
  ## Examples
  
      iex> update_program(program, %{field: new_value})
      {:ok, %program{}}
  
      iex> update_program(program, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  
  """
  def update_program(%Program{} = program, attrs) do
    program
    |> Program.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a program.
  
  ## Examples
  
      iex> delete_program(program)
      {:ok, %program{}}
  
      iex> delete_program(program)
      {:error, %Ecto.Changeset{}}
  
  """
  def delete_program(%Program{} = program) do
    Repo.delete(program)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking program changes.
  
  ## Examples
  
      iex> change_program(program)
      %Ecto.Changeset{data: %program{}}
  
  """
  def change_Program(%Program{} = program, attrs \\ %{}) do
    Program.changeset(program, attrs)
  end
end
