defmodule Dbservice.Programs do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Programs.Program
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of program.
  ## Examples
      iex> list_group()
      [%Group{}, ...]
  """
  def list_program do
    Repo.all(Program)
  end

  @doc """
  Gets a single program.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_program!(123)
      %Group{}
      iex> get_program!(456)
      ** (Ecto.NoResultsError)
  """
  def get_program!(id), do: Repo.get!(Program, id)

  @doc """
  Gets a Program by program name
  """

  def get_program_by_name(name) do
    Repo.get_by(Program, name: name)
  end

  @doc """
  Creates a program.
  ## Examples
      iex> create_program(%{field: value})
      {:ok, %Group{}}
      iex> create_program(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_program(attrs \\ %{}) do
    %Program{}
    |> Program.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "program", child_id: attrs["id"]}])
    |> Repo.insert()
  end

  @doc """
  Updates a program.
  ## Examples
      iex> update_program(program, %{field: new_value})
      {:ok, %Group{}}
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
      {:ok, %GroupUser{}}
      iex> delete_program(program)
      {:error, %Ecto.Changeset{}}
  """
  def delete_program(%Program{} = program) do
    Repo.delete(program)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  ## Examples
      iex> change_program(program)
      %Ecto.Changeset{data: %Groupuser{}}
  """
  def change_program(%Program{} = program, attrs \\ %{}) do
    Program.changeset(program, attrs)
  end
end
