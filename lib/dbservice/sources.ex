defmodule Dbservice.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Sources.Source

  @doc """
  Returns the list of source.
  ## Examples
      iex> list_source()
      [%Source{}, ...]
  """
  def list_source do
    Repo.all(Source)
  end

  @doc """
  Gets a single source.
  Raises `Ecto.NoResultsError` if the source does not exist.
  ## Examples
      iex> get_source!(123)
      %Source{}
      iex> get_source!(456)
      ** (Ecto.NoResultsError)
  """
  def get_source!(id), do: Repo.get!(Source, id)

  @doc """
  Gets a source by link.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_source_by_link(12)
      %School{}

      iex> get_source_by_link(12)
      ** (Ecto.NoResultsError)

  """
  def get_source_by_link(link) do
    Repo.get_by(Source, link: link)
  end

  @doc """
  Creates a source.
  ## Examples
      iex> create_source(%{field: value})
      {:ok, %Source{}}
      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_source(attrs \\ %{}) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a source.
  ## Examples
      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}
      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a source.
  ## Examples
      iex> delete_source(source)
      {:ok, %Source{}}
      iex> delete_source(source)
      {:error, %Ecto.Changeset{}}
  """
  def delete_source(%Source{} = source) do
    Repo.delete(source)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.
  ## Examples
      iex> change_source(source)
      %Ecto.Changeset{data: %Source{}}
  """
  def change_source(%Source{} = source, attrs \\ %{}) do
    Source.changeset(source, attrs)
  end
end
