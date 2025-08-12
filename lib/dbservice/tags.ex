defmodule Dbservice.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Tags.Tag

  @doc """
  Returns the list of tag.
  ## Examples
      iex> list_tag()
      [%Tag{}, ...]
  """
  def list_tag do
    Repo.all(Tag)
  end

  @doc """
  Gets a single tag.
  Raises `Ecto.NoResultsError` if the tag does not exist.
  ## Examples
      iex> get_tag!(123)
      %Tag{}
      iex> get_tag!(456)
      ** (Ecto.NoResultsError)
  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Creates a tag.
  ## Examples
      iex> create_tag(%{field: value})
      {:ok, %Tag{}}
      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.
  ## Examples
      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}
      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag.
  ## Examples
      iex> delete_tag(tag)
      {:ok, %Tag{}}
      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}
  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.
  ## Examples
      iex> change_tag(tag)
      %Ecto.Changeset{data: %Tag{}}
  """
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  @doc """
  Gets a tag by name. Returns nil if not found.
  """
  def get_tag_by_name(name) do
    Repo.get_by(Tag, name: name)
  end
end
