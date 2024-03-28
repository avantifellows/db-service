defmodule Dbservice.Subjects do
  @moduledoc """
  The Subjects context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Subjects.Subject

  @doc """
  Returns the list of subject.
  ## Examples
      iex> list_subject()
      [%Subject{}, ...]
  """
  def list_subject do
    Repo.all(Subject)
  end

  @doc """
  Gets a single subject.
  Raises `Ecto.NoResultsError` if the subject does not exist.
  ## Examples
      iex> get_subject!(123)
      %Subject{}
      iex> get_subject!(456)
      ** (Ecto.NoResultsError)
  """
  def get_subject!(id), do: Repo.get!(Subject, id)

  @doc """
  Gets a subject by name.
  
  Raises `Ecto.NoResultsError` if the School does not exist.
  
  ## Examples
  
      iex> get_subject_by_name(Sankalp)
      %School{}
  
      iex> get_subject_by_name(Sankalp)
      ** (Ecto.NoResultsError)
  
  """
  def get_subject_by_name(name) do
    Repo.get_by(Subject, name: name)
  end

  @doc """
  Creates a subject.
  ## Examples
      iex> create_subject(%{field: value})
      {:ok, %Subject{}}
      iex> create_subject(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_subject(attrs \\ %{}) do
    %Subject{}
    |> Subject.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subject.
  ## Examples
      iex> update_subject(subject, %{field: new_value})
      {:ok, %Subject{}}
      iex> update_subject(subject, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_subject(%Subject{} = subject, attrs) do
    subject
    |> Subject.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subject.
  ## Examples
      iex> delete_subject(subject)
      {:ok, %Subject{}}
      iex> delete_subject(subject)
      {:error, %Ecto.Changeset{}}
  """
  def delete_subject(%Subject{} = subject) do
    Repo.delete(subject)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subject changes.
  ## Examples
      iex> change_subject(subject)
      %Ecto.Changeset{data: %Subject{}}
  """
  def change_subject(%Subject{} = subject, attrs \\ %{}) do
    Subject.changeset(subject, attrs)
  end
end
