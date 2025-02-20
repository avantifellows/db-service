defmodule Dbservice.DataImport do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.DataImport.Import

  @doc """
  Returns the list of Import.
  ## Examples
      iex> list_imports()
      [%Import{}, ...]
  """
  def list_imports do
    Repo.all(from i in Import, order_by: [desc: i.inserted_at])
  end

  @doc """
  Gets a single Import.
  Raises `Ecto.NoResultsError` if the Import does not exist.
  ## Examples
      iex> get_import!(123)
      %Import{}
      iex> get_import!(456)
      ** (Ecto.NoResultsError)
  """
  def get_import!(id), do: Repo.get!(Import, id)

  @doc """
  Creates a import.
  ## Examples
      iex> create_import(%{field: value})
      {:ok, %Import{}}
      iex> create_import(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_import(attrs \\ %{}) do
    %Import{}
    |> Import.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a import.
  ## Examples
      iex> update_import(Import, %{field: new_value})
      {:ok, %Import{}}
      iex> update_import(Import, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_import(%Import{} = data_import, attrs) do
    data_import
    |> Import.changeset(attrs)
    |> Repo.update()
  end
end
