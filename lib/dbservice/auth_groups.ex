defmodule Dbservice.AuthGroup do
  @moduledoc """
  The AuthGroup context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Groups.Group.AuthGroup

  @doc """
  Returns the list of auth groups.
  ## Examples
      iex> list_auth_group()
      [%AuthGroup{}, ...]
  """
  def list_auth_group do
    Repo.all(AuthGroup)
  end

  @doc """
  Gets a single auth-group.
  Raises `Ecto.NoResultsError` if the AuthGroup does not exist.
  ## Examples
      iex> get_auth_group!(123)
      %AuthGroup{}
      iex> get_auth_group!(456)
      ** (Ecto.NoResultsError)
  """
  def get_auth_group!(id) do
    Repo.get!(AuthGroup, id) |> Repo.preload(:group_type)
  end

  @doc """
  Gets an auth group by name.
  Raises `Ecto.NoResultsError` if the AuthGroup does not exist.
  ## Examples
      iex> get_auth_group_by_name(DelhiStudents)
      %AuthGroup{}
      iex> get_auth_group_by_name(abc)
      ** (Ecto.NoResultsError)
  """
  def get_auth_group_by_name(name) do
    Repo.get_by(AuthGroup, name: name)
  end

  @doc """
  Creates an auth group.
  ## Examples
      iex> create_auth_group(%{field: value})
      {:ok, %AuthGroup{}}
      iex> create_auth_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_auth_group(attrs \\ %{}) do
    %AuthGroup{}
    |> AuthGroup.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group_type, [
      %GroupType{type: "auth_group", child_id: attrs["id"]}
    ])
    |> Repo.insert()
  end

  @doc """
  Updates an auth group.
  ## Examples
      iex> update_auth_group(auth_group, %{field: new_value})
      {:ok, %AuthGroup{}}
      iex> update_auth_group(auth_group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_auth_group(%AuthGroup{} = auth_group, attrs) do
    auth_group
    |> AuthGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an auth group.
  ## Examples
      iex> delete_auth_group(auth_group)
      {:ok, %AuthGroup{}}
      iex> delete_auth_group(auth_group)
      {:error, %Ecto.Changeset{}}
  """
  def delete_auth_group(%AuthGroup{} = auth_group) do
    Repo.delete(auth_group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking auth_group changes.
  ## Examples
      iex> change_auth_group(auth_group)
      %Ecto.Changeset{data: %AuthGroup{}}
  """
  def change_auth_group(%AuthGroup{} = auth_group, attrs \\ %{}) do
    AuthGroup.changeset(auth_group, attrs)
  end
end
