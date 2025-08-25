defmodule Dbservice.Sessions do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Sessions.Session

  @doc """
  Returns the list of session.

  ## Examples

      iex> list_session()
      [%Session{}, ...]

  """
  def list_session do
    Repo.all(Session)
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.

  ## Examples

      iex> get_session!(123)
      %Session{}

      iex> get_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Gets a session by session ID.
  Raises `Ecto.NoResultsError` if the Session does not exist.
  ## Examples
      iex> get_session_by_session_id(AFStudents)
      %Session{}
      iex> get_session_by_session_id(AvantiStudents)
      ** (Ecto.NoResultsError)
  """
  def get_session_by_session_id(session_id) do
    Repo.get_by(Session, session_id: session_id)
  end

  @doc """
  Creates a session.

  ## Examples

      iex> create_session(%{field: value})
      {:ok, %Session{}}

      iex> create_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session.

  ## Examples

      iex> update_session(session, %{field: new_value})
      {:ok, %Session{}}

      iex> update_session(session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session.

  ## Examples

      iex> delete_session(session)
      {:ok, %Session{}}

      iex> delete_session(session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.

  ## Examples

      iex> change_session(session)
      %Ecto.Changeset{data: %Session{}}

  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Updates the groups mapped to a session.
  """
  def update_groups(session_id, group_ids) when is_list(group_ids) do
    session = get_session!(session_id)

    groups =
      Dbservice.Groups.Group
      |> where([group], group.id in ^group_ids)
      |> Repo.all()

    session
    |> Repo.preload(:group)
    |> Session.changeset_update_groups(groups)
    |> Repo.update()
  end

  alias Dbservice.Sessions.SessionOccurrence

  @doc """
  Returns the list of session_occurrence.

  ## Examples

      iex> list_session_occurrence()
      [%SessionOccurrence{}, ...]

  """
  def list_session_occurrence do
    Repo.all(SessionOccurrence)
  end

  @doc """
  Gets a single session_occurrence.

  Raises `Ecto.NoResultsError` if the Session occurence does not exist.

  ## Examples

      iex> get_session_occurrence!(123)
      %SessionOccurrence{}

      iex> get_session_occurrence!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session_occurrence!(id) do
    Repo.get!(SessionOccurrence, id)
  end

  @doc """
  Creates a session_occurrence.

  ## Examples

      iex> create_session_occurrence(%{field: value})
      {:ok, %SessionOccurrence{}}

      iex> create_session_occurrence(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_session_occurrence(attrs \\ %{}) do
    %SessionOccurrence{}
    |> SessionOccurrence.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session_occurrence.

  ## Examples

      iex> update_session_occurrence(session_occurrence, %{field: new_value})
      {:ok, %SessionOccurrence{}}

      iex> update_session_occurrence(session_occurrence, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_session_occurrence(%SessionOccurrence{} = session_occurrence, attrs) do
    session_occurrence
    |> SessionOccurrence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session_occurrence.

  ## Examples

      iex> delete_session_occurrence(session_occurrence)
      {:ok, %SessionOccurrence{}}

      iex> delete_session_occurrence(session_occurrence)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session_occurrence(%SessionOccurrence{} = session_occurrence) do
    Repo.delete(session_occurrence)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session_occurrence changes.

  ## Examples

      iex> change_session_occurrence(session_occurrence)
      %Ecto.Changeset{data: %SessionOccurrence{}}

  """
  def change_session_occurrence(%SessionOccurrence{} = session_occurrence, attrs \\ %{}) do
    SessionOccurrence.changeset(session_occurrence, attrs)
  end

  alias Dbservice.Sessions.UserSession

  @doc """
  Returns the list of user_session.

  ## Examples

      iex> list_user_session()
      [%UserSession{}, ...]

  """
  def list_user_session do
    Repo.all(UserSession)
  end

  @doc """
  Gets a single user_session.

  Raises `Ecto.NoResultsError` if the User session does not exist.

  ## Examples

      iex> get_user_session!(123)
      %UserSession{}

      iex> get_user_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_session!(id), do: Repo.get!(UserSession, id)

  @doc """
  Creates a user_session.

  ## Examples

      iex> create_user_session(%{field: value})
      {:ok, %UserSession{}}

      iex> create_user_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_session(attrs \\ %{}) do
    %UserSession{}
    |> UserSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_session.

  ## Examples

      iex> update_user_session(user_session, %{field: new_value})
      {:ok, %UserSession{}}

      iex> update_user_session(user_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_session(%UserSession{} = user_session, attrs) do
    user_session
    |> UserSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_session.

  ## Examples

      iex> delete_user_session(user_session)
      {:ok, %UserSession{}}

      iex> delete_user_session(user_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_session(%UserSession{} = user_session) do
    Repo.delete(user_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_session changes.

  ## Examples

      iex> change_user_session(user_session)
      %Ecto.Changeset{data: %UserSession{}}

  """
  def change_user_session(%UserSession{} = user_session, attrs \\ %{}) do
    UserSession.changeset(user_session, attrs)
  end

  @doc """
  Deletes all user_session rows for a given user.

  Returns {:ok, count}.
  """
  def delete_user_sessions_by_user_id(user_id) do
    {count, _} = from(us in UserSession, where: us.user_id == ^user_id) |> Repo.delete_all()
    {:ok, count}
  end
end
