defmodule Dbservice.GroupTypes do
  @moduledoc """
  The GroupTypes context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.GroupTypes.GroupType
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of group_type.

  ## Examples

      iex> list_group()
      [%GroupType{}, ...]

  """
  def list_group_type do
    Repo.all(GroupType)
  end

  @doc """
  Gets a single group_type.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group_type!(123)
      %GroupType{}

      iex> get_group_type!(456)
      ** (Ecto.NoResultsError)

"""
  def get_group_type!(id), do: Repo.get!(GroupType, id)

  @doc """
  Creates a group_type.

  ## Examples

      iex> create_group_type(%{field: value})
      {:ok, %GroupType{}}

      iex> create_group_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group_type(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group_type.

  ## Examples

      iex> update_group_type(group_type, %{field: new_value})
      {:ok, %GroupType{}}

      iex> update_group_type(group_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group_type(%GroupType{} = group_type, attrs) do
    group_type
    |> GroupType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group_type.

  ## Examples

      iex> delete_group_type(group_type)
      {:ok, %GroupUser{}}

      iex> delete_group_type(group_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group_type(%GroupType{} = group_type) do
    Repo.delete(group_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group_type(group_type)
      %Ecto.Changeset{data: %Groupuser{}}

  """
  def change_group_type(%GroupType{} = group_type, attrs \\ %{}) do
    GroupType.changeset(group_type, attrs)
  end
end
