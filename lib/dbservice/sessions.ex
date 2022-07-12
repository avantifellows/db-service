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
  Updates the batches mapped to a session.
  """
  def update_batches(session_id, batch_ids) when is_list(batch_ids) do
    session = get_session!(session_id)

    batches =
      Dbservice.Batches.Batch
      |> where([batch], batch.id in ^batch_ids)
      |> Repo.all()

    session
    |> Repo.preload(:batches)
    |> Session.changeset_update_batches(batches)
    |> Repo.update()
  end

  alias Dbservice.Sessions.SessionOccurence

  @doc """
  Returns the list of session_occurence.

  ## Examples

      iex> list_session_occurence()
      [%SessionOccurence{}, ...]

  """
  def list_session_occurence do
    Repo.all(SessionOccurence)
  end

  @doc """
  Gets a single session_occurence.

  Raises `Ecto.NoResultsError` if the Session occurence does not exist.

  ## Examples

      iex> get_session_occurence!(123)
      %SessionOccurence{}

      iex> get_session_occurence!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session_occurence!(id) do
    Repo.get!(SessionOccurence, id)
  end

  @doc """
  Creates a session_occurence.

  ## Examples

      iex> create_session_occurence(%{field: value})
      {:ok, %SessionOccurence{}}

      iex> create_session_occurence(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_session_occurence(attrs \\ %{}) do
    %SessionOccurence{}
    |> SessionOccurence.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session_occurence.

  ## Examples

      iex> update_session_occurence(session_occurence, %{field: new_value})
      {:ok, %SessionOccurence{}}

      iex> update_session_occurence(session_occurence, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_session_occurence(%SessionOccurence{} = session_occurence, attrs) do
    session_occurence
    |> SessionOccurence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session_occurence.

  ## Examples

      iex> delete_session_occurence(session_occurence)
      {:ok, %SessionOccurence{}}

      iex> delete_session_occurence(session_occurence)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session_occurence(%SessionOccurence{} = session_occurence) do
    Repo.delete(session_occurence)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session_occurence changes.

  ## Examples

      iex> change_session_occurence(session_occurence)
      %Ecto.Changeset{data: %SessionOccurence{}}

  """
  def change_session_occurence(%SessionOccurence{} = session_occurence, attrs \\ %{}) do
    SessionOccurence.changeset(session_occurence, attrs)
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
end
