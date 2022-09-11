# defmodule Dbservice.Batches do
#   @moduledoc """
#   The Batches context.
#   """

#   import Ecto.Query, warn: false
#   alias Dbservice.Repo

#   alias Dbservice.Batches.Batch

#   @doc """
#   Returns the list of batch.

#   ## Examples

#       iex> list_batch()
#       [%Batch{}, ...]

#   """
#   def list_batch do
#     Repo.all(Batch)
#   end

#   @doc """
#   Gets a single batch.

#   Raises `Ecto.NoResultsError` if the Batch does not exist.

#   ## Examples

#       iex> get_batch!(123)
#       %Batch{}

#       iex> get_batch!(456)
#       ** (Ecto.NoResultsError)

#   """
#   def get_batch!(id), do: Repo.get!(Batch, id)

#   @doc """
#   Creates a batch.

#   ## Examples

#       iex> create_batch(%{field: value})
#       {:ok, %Batch{}}

#       iex> create_batch(%{field: bad_value})
#       {:error, %Ecto.Changeset{}}

#   """
#   def create_batch(attrs \\ %{}) do
#     %Batch{}
#     |> Batch.changeset(attrs)
#     |> Repo.insert()
#   end

#   @doc """
#   Updates a batch.

#   ## Examples

#       iex> update_batch(batch, %{field: new_value})
#       {:ok, %Batch{}}

#       iex> update_batch(batch, %{field: bad_value})
#       {:error, %Ecto.Changeset{}}

#   """
#   def update_batch(%Batch{} = batch, attrs) do
#     batch
#     |> Batch.changeset(attrs)
#     |> Repo.update()
#   end

#   @doc """
#   Deletes a batch.

#   ## Examples

#       iex> delete_batch(batch)
#       {:ok, %Batch{}}

#       iex> delete_batch(batch)
#       {:error, %Ecto.Changeset{}}

#   """
#   def delete_batch(%Batch{} = batch) do
#     Repo.delete(batch)
#   end

#   @doc """
#   Returns an `%Ecto.Changeset{}` for tracking batch changes.

#   ## Examples

#       iex> change_batch(batch)
#       %Ecto.Changeset{data: %Batch{}}

#   """
#   def change_batch(%Batch{} = batch, attrs \\ %{}) do
#     Batch.changeset(batch, attrs)
#   end

#   @doc """
#   Updates the users mapped to a batch.
#   """
#   def update_users(batch_id, user_ids) when is_list(user_ids) do
#     batch = get_batch!(batch_id)

#     users =
#       Dbservice.Users.User
#       |> where([user], user.id in ^user_ids)
#       |> Repo.all()

#     batch
#     |> Repo.preload(:users)
#     |> Batch.changeset_update_users(users)
#     |> Repo.update()
#   end

#   @doc """
#   Updates the sessions mapped to a batch.
#   """
#   def update_sessions(batch_id, session_ids) when is_list(session_ids) do
#     batch = get_batch!(batch_id)

#     sessions =
#       Dbservice.Sessions.Session
#       |> where([session], session.id in ^session_ids)
#       |> Repo.all()

#     batch
#     |> Repo.preload(:sessions)
#     |> Batch.changeset_update_sessions(sessions)
#     |> Repo.update()
#   end
# end
