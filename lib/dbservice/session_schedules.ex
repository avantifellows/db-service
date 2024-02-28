defmodule Dbservice.SessionSchedules do
  @moduledoc """
  The SessionSchedules context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Sessions.SessionSchedule

  @doc """
  Returns the list of session_schedule.
  ## Examples
      iex> list_session_schedule()
      [%SessionSchedule{}, ...]
  """
  def list_session_schedule do
    Repo.all(SessionSchedule)
  end

  @doc """
  Gets a single session_schedule.
  Raises `Ecto.NoResultsError` if the session_schedule does not exist.
  ## Examples
      iex> get_session_schedule!(123)
      %SessionSchedule{}
      iex> get_session_schedule!(456)
      ** (Ecto.NoResultsError)
  """
  def get_session_schedule!(id), do: Repo.get!(SessionSchedule, id)

  @doc """
  Creates a session_schedule.
  ## Examples
      iex> create_session_schedule(%{field: value})
      {:ok, %SessionSchedule{}}
      iex> create_session_schedule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_session_schedule(attrs \\ %{}) do
    %SessionSchedule{}
    |> SessionSchedule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session_schedule.
  ## Examples
      iex> update_session_schedule(session_schedule, %{field: new_value})
      {:ok, %SessionSchedule{}}
      iex> update_session_schedule(session_schedule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_session_schedule(%SessionSchedule{} = session_schedule, attrs) do
    session_schedule
    |> SessionSchedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session_schedule.
  ## Examples
      iex> delete_session_schedule(session_schedule)
      {:ok, %SessionSchedule{}}
      iex> delete_session_schedule(session_schedule)
      {:error, %Ecto.Changeset{}}
  """
  def delete_session_schedule(%SessionSchedule{} = session_schedule) do
    Repo.delete(session_schedule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session_schedule changes.
  ## Examples
      iex> change_session_schedule(session_schedule)
      %Ecto.Changeset{data: %SessionSchedule{}}
  """
  def change_session_schedule(%SessionSchedule{} = session_schedule, attrs \\ %{}) do
    SessionSchedule.changeset(session_schedule, attrs)
  end
end
