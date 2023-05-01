defmodule Dbservice.GroupTypes do
  @moduledoc """
  The GroupTypes context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Groups.GroupSession
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Groups.GroupType

  @doc """
  Returns the list of group_type.
  ## Examples
      iex> list_group_type()
      [%GroupType{}, ...]
  """
  def list_group_type do
    Repo.all(GroupType)
  end

  @doc """
  Gets a single group_type.
  Raises `Ecto.NoResultsError` if the GroupType does not exist.
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
      iex> create_group_type_type(%{field: value})
      {:ok, %GroupType{}}
      iex> create_group_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_group_type(attrs \\ %{}) do
    %GroupType{}
    |> GroupType.changeset(attrs)
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
  def update_group_type(%GroupType{} = group, attrs) do
    group
    |> GroupType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group_type.
  ## Examples
      iex> delete_group_type(group)
      {:ok, %Group{}}
      iex> delete_group_type(group)
      {:error, %Ecto.Changeset{}}
  """
  def delete_group_type(%GroupType{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group_type changes.
  ## Examples
      iex> change_group_type(group_type)
      %Ecto.Changeset{data: %GroupType{}}
  """
  def change_group_type(%GroupType{} = group, attrs \\ %{}) do
    GroupType.changeset(group, attrs)
  end

  @doc """
  Updates the users mapped to a group_type.
  """
  def update_users(group_id, user_ids) when is_list(user_ids) do
    group = get_group_type!(group_id)

    users =
      Dbservice.Users.User
      |> where([user], user.id in ^user_ids)
      |> Repo.all()

    group
    |> Repo.preload(:user)
    |> GroupUser.changeset_update_users(users)
    |> Repo.update()
  end

  @doc """
  Updates the sessions mapped to a group.
  """
  def update_sessions(group_id, session_ids) when is_list(session_ids) do
    group = get_group_type!(group_id)

    sessions =
      Dbservice.Sessions.Session
      |> where([session], session.id in ^session_ids)
      |> Repo.all()

    group
    |> Repo.preload(:session)
    |> GroupSession.changeset_update_sessions(sessions)
    |> Repo.update()
  end
end
