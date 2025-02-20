defmodule Dbservice.Languages do
  @moduledoc """
  The Exams context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Languages.Language

  @doc """
  Returns the list of Languages.
  ## Examples
      iex> list_language()
      [%Language{}, ...]
  """
  def list_language do
    Repo.all(Language)
  end

  @doc """
  Gets a single language.
  Raises `Ecto.NoResultsError` if the Language does not exist.
  ## Examples
      iex> get_language!(123)
      %Language{}
      iex> get_language!(456)
      ** (Ecto.NoResultsError)
  """
  def get_language!(id) do
    Repo.get!(Language, id)
  end

  @doc """
  Gets a Language by name.
  Raises `Ecto.NoResultsError` if the Language does not exist.
  ## Examples
      iex> get_language_by_name(JEE)
      %Language{}
      iex> get_language_by_name(123)
      ** (Ecto.NoResultsError)
  """
  def get_language_by_name(name) do
    Repo.get_by(Language, name: name)
  end

  @doc """
  Creates a Language.
  ## Examples
      iex> create_language(%{field: value})
      {:ok, %Language{}}
      iex> create_language(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_language(attrs \\ %{}) do
    %Language{}
    |> Language.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Language.
  ## Examples
      iex> update_language(language, %{field: new_value})
      {:ok, %Language{}}
      iex> update_language(language, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_language(%Language{} = language, attrs) do
    language
    |> Language.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Language.
  ## Examples
      iex> delete_language(language)
      {:ok, %Language{}}
      iex> delete_language(language)
      {:error, %Ecto.Changeset{}}
  """
  def delete_language(%Language{} = language) do
    Repo.delete(language)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking Language changes.
  ## Examples
      iex> change_language(language)
      %Ecto.Changeset{data: %Language{}}
  """
  def change_language(%Language{} = language, attrs \\ %{}) do
    Language.changeset(language, attrs)
  end
end
