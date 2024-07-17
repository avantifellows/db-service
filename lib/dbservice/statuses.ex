defmodule Dbservice.Statuses do
  @moduledoc """
  The Statuses context.
  """

  import Ecto.Query, warn: false
  alias Faker.Internet.StatusCode
  alias Dbservice.Repo

  alias Dbservice.Statuses.Status
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of status.
  ## Examples
      iex> list_status()
      [%Status{}, ...]
  """
  def list_status do
    Repo.all(Status)
  end

  @doc """
  Gets a single status.
  Raises `Ecto.NoResultsError` if the status does not exist.
  ## Examples
      iex> get_status!(123)
      %Status{}
      iex> get_status!(456)
      ** (Ecto.NoResultsError)
  """
  def get_status!(id), do: Repo.get!(StatusCode, id)

  @doc """
  Creates a status.
  ## Examples
      iex> create_status(%{field: value})
      {:ok, %Status{}}
      iex> create_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_status(attrs \\ %{}) do
    %Status{}
    |> Status.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "status", child_id: attrs["id"]}])
    |> Repo.insert()
  end

  @doc """
  Updates a status.
  ## Examples
      iex> update_status(status, %{field: new_value})
      {:ok, %Status{}}
      iex> update_status(status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_status(%Status{} = status, attrs) do
    status
    |> Status.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a status.
  ## Examples
      iex> delete_status(status)
      {:ok, %Status{}}
      iex> delete_status(status)
      {:error, %Ecto.Changeset{}}
  """
  def delete_status(%Status{} = status) do
    Repo.delete(status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking status changes.
  ## Examples
      iex> change_status(status)
      %Ecto.Changeset{data: %Status{}}
  """
  def change_status(%Status{} = status, attrs \\ %{}) do
    Status.changeset(status, attrs)
  end
end
