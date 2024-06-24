defmodule Dbservice.Groups do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Groups.GroupSession
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of groups.
  ## Examples
      iex> list_group()
      [%Group{}, ...]
  """
  def list_group do
    Repo.all(Group)
  end

  @doc """
  Gets a single group.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_group!(123)
      %Group{}
      iex> get_group!(456)
      ** (Ecto.NoResultsError)
  """
  def get_group!(id), do: Repo.get!(Group, id)

  @doc """
  Gets group by group_id and type.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_group_by_group_id_and_type(123, "name")
      %Group{}
      iex> get_group_by_group_id_and_type(456, "name")
      ** (Ecto.NoResultsError)
  """
  def get_group_by_group_id_and_type(group_id, type) do
    Repo.get_by(Group, id: group_id, type: type)
  end

  @doc """
  Gets group by child_id.
  Raises `Ecto.NoResultsError` if the Group does not exist.
  ## Examples
      iex> get_group_by_child_id(123)
      %Group{}
      iex> get_group_by_child_id(456)
      ** (Ecto.NoResultsError)
  """
  def get_group_by_child_id(child_id) do
    Repo.get_by(Group, child_id: child_id, type: "batch")
  end

  @doc """
  Creates a group.
  ## Examples
      iex> create_group(%{field: value})
      {:ok, %Group{}}
      iex> create_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group.
  ## Examples
      iex> update_group(group, %{field: new_value})
      {:ok, %Group{}}
      iex> update_group(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group.
  ## Examples
      iex> delete_group(group)
      {:ok, %Group{}}
      iex> delete_group(group)
      {:error, %Ecto.Changeset{}}
  """
  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  ## Examples
      iex> change_group(group)
      %Ecto.Changeset{data: %Group{}}
  """
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  @doc """
  Updates the users mapped to a group.
  """
  def update_users(group_id, user_ids) when is_list(user_ids) do
    group = get_group!(group_id)

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
    group = get_group!(group_id)

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
