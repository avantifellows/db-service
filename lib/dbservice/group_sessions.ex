defmodule Dbservice.GroupSessions do
  @moduledoc """
  The GroupSessions context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Groups.GroupSession

  @doc """
  Returns the list of group_session.

  ## Examples

      iex> list_group_session()
      [%Group{}, ...]

  """
  def list_group_session do
    Repo.all(GroupSession)
  end

  @doc """
  Gets a single group_session.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group_session!(123)
      %Group{}

      iex> get_group_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group_session!(id), do: Repo.get!(GroupSession, id)

  @doc """
  Gets a group-session by session ID.
  Raises `Ecto.NoResultsError` if the GroupSession does not exist.
  ## Examples
      iex> get_group_session_by_session_id(1234)
      %GroupSession{}
      iex> get_group_session_by_session_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_group_session_by_session_id(session_id) do
    Repo.get_by(GroupSession, session_id: session_id)
  end

  @doc """
    Gets all group-sessions by session ID.
    Returns an empty list if no GroupSessions exist for the given session ID.
    ## Examples
        iex> get_all_group_sessions_by_session_id(1234)
        [%GroupSession{}, ...]

        iex> get_all_group_sessions_by_session_id(9999)
        []
  """

  def get_all_group_sessions_by_session_id(session_id) do
    from(gs in GroupSession, where: gs.session_id == ^session_id)
    |> Repo.all()
  end

  @doc """
  Gets a group-session by group ID.
  Raises `Ecto.NoResultsError` if the GroupSession does not exist.
  ## Examples
      iex> get_group_session_by_group_id(1234)
      %GroupSession{}
      iex> get_group_session_by_group_id(abc)
      ** (Ecto.NoResultsError)
  """

  def get_group_session_by_group_id(group_id) do
    from(g in GroupSession, where: g.group_id == ^group_id)
    |> Repo.all()
  end

  @doc """
  Creates a group_session.

  ## Examples

      iex> create_group_session(%{field: value})
      {:ok, %Group{}}

      iex> create_group_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group_session(attrs \\ %{}) do
    %GroupSession{}
    |> GroupSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group_session.

  ## Examples

      iex> update_group_session(group_session, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group_session(group_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group_session(%GroupSession{} = group_session, attrs) do
    group_session
    |> GroupSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group_user.

  ## Examples

      iex> delete_group_session(group_session)
      {:ok, %GroupUser{}}

      iex> delete_group_session(group_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group_session(%GroupSession{} = group_session) do
    Repo.delete(group_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group_session(group_session)
      %Ecto.Changeset{data: %Groupuser{}}

  """
  def change_group_session(%GroupSession{} = group_session, attrs \\ %{}) do
    GroupSession.changeset(group_session, attrs)
  end
end
