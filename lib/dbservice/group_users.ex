defmodule Dbservice.GroupUsers do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Groups.GroupUser
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of group_user.

  ## Examples

      iex> list_group()
      [%Group{}, ...]

  """
  def list_group_user do
    Repo.all(GroupUser)
  end

  @doc """
  Gets a single group_user.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group_user!(123)
      %Group{}

      iex> get_group_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group_user!(id), do: Repo.get!(GroupUser, id)

  @doc """
  Gets a group-user based on user_id and group_id.
  Raises `Ecto.NoResultsError` if the GroupUser does not exist.
  ## Examples
      iex> get_group_user_by_user_id_and_group_id(1, 2)
      %GroupUser{}
      iex> get_group_user_by_user_id_and_group_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_group_user_by_user_id_and_group_id(user_id, group_id) do
    Repo.get_by(GroupUser, user_id: user_id, group_id: group_id)
  end

  def get_group_user_with_type(user_id, type) do
    from(gu in GroupUser,
      join: g in Group,
      on: gu.group_id == g.id,
      where: gu.user_id == ^user_id and g.type == ^type,
      select: gu
    )
    |> Repo.all()
  end

  @doc """
  Gets a group-user by user ID.
  Raises `Ecto.NoResultsError` if the GroupUser does not exist.
  ## Examples
      iex> get_group_user_by_user_id(1234)
      %GroupUser{}
      iex> get_group_user_by_user_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_group_user_by_user_id(user_id) do
    from(g in GroupUser, where: g.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Creates a group_user.

  ## Examples

      iex> create_group_user(%{field: value})
      {:ok, %Group{}}

      iex> create_group_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group_user(attrs \\ %{}) do
    %GroupUser{}
    |> GroupUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group_user.

  ## Examples

      iex> update_group_user(group_user, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group_user(group_user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group_user(%GroupUser{} = group_user, attrs) do
    group_user
    |> GroupUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group_user.

  ## Examples

      iex> delete_group_user(group_user)
      {:ok, %GroupUser{}}

      iex> delete_group_user(group_user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group_user(%GroupUser{} = group_user) do
    Repo.delete(group_user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group_user(group_user)
      %Ecto.Changeset{data: %Groupuser{}}

  """
  def change_group_user(%GroupUser{} = group_user, attrs \\ %{}) do
    GroupUser.changeset(group_user, attrs)
  end
end
