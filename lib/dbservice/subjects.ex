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
  Creates one or more subjects.

  ## Examples
      iex> create_subjects([%{field: value}])
      {:ok, [%Subject{}]}
      iex> create_subjects([%{field: value}, %{field: value}])
      {:ok, [%Subject{}, %Subject{}]}
      iex> create_subjects([%{field: bad_value}])
      {:error, %{}}
  """

  def create_subjects([]), do: {:error, %{}}

  def create_subjects(params) do
    Enum.reduce(params, {:ok, []}, fn attrs, {:ok, subjects} ->
      case create_subject(attrs) do
        {:ok, subject} ->
          {:ok, [subject | subjects]}

        {:error, _changeset} ->
          {:error, %{}}
      end
    end)
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
