defmodule Dbservice.Batches do
  @moduledoc """
  The Batches context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of batch.
  ## Examples
      iex> list_batch()
      [%Batch{}, ...]
  """
  def list_batch do
    Repo.all(Batch)
  end

  @doc """
  Gets a single batch.
  Raises `Ecto.NoResultsError` if the batch does not exist.
  ## Examples
      iex> get_batch!(123)
      %Batch{}
      iex> get_batch!(456)
      ** (Ecto.NoResultsError)
  """
  def get_batch!(id), do: Repo.get!(Batch, id)

  @doc """
  Gets a Batch by batch ID.
  Raises `Ecto.NoResultsError` if the Batch does not exist.
  ## Examples
      iex> get_batch_by_batch_id(1234)
      %Batch{}
      iex> get_batch_by_batch_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_batch_by_batch_id(batch_id) do
    Repo.get_by(Batch, batch_id: batch_id)
  end

  @doc """
  Creates a batch.
  ## Examples
      iex> create_batch(%{field: value})
      {:ok, %Batch{}}
      iex> create_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_batch(attrs \\ %{}) do
    %Batch{}
    |> Batch.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "batch", child_id: attrs["id"]}])
    |> Repo.insert()
  end

  @doc """
  Gets a batch by batch_id. Returns nil if not found.
  """
  def get_batch_by_batch_id_nil(batch_id) when is_binary(batch_id) do
    batch_id = String.trim(batch_id)
    if batch_id == "", do: nil, else: Repo.get_by(Batch, batch_id: batch_id)
  end

  def get_batch_by_batch_id_nil(_), do: nil

  @doc """
  Creates a batch and its group row (child_id = batch.id, type \"batch\").
  Used by data import.
  """
  def create_batch_from_import(attrs) when is_map(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:batch, Batch.changeset(%Batch{}, attrs))
    |> Ecto.Multi.insert(:group, fn %{batch: b} ->
      Group.changeset(%Group{}, %{type: "batch", child_id: b.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{batch: b}} -> {:ok, b}
      {:error, :batch, changeset, _} -> {:error, changeset}
      {:error, :group, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates a batch.
  ## Examples
      iex> update_batch(batch, %{field: new_value})
      {:ok, %Batch{}}
      iex> update_batch(batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_batch(%Batch{} = batch, attrs) do
    batch
    |> Batch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Corrects a batch's `batch_id` in place (e.g. fixing a typo), looking the batch up by its
  current `old_batch_id` and renaming it to `new_batch_id`.

  Enrollment records and group_user mappings reference a batch by its primary key, not by the
  `batch_id` string, so the rename is self-contained - every enrollment stays with the batch.

  Returns:
  - `{:ok, %Batch{}}` on success
  - `{:error, reason}` when an id is blank, no batch has `old_batch_id`, more than one batch
    shares it, or `new_batch_id` is already used by a different batch
  """
  def correct_batch_id(old_batch_id, new_batch_id) do
    with {:ok, old_id} <- require_batch_id(old_batch_id, "old_batch_id"),
         {:ok, new_id} <- require_batch_id(new_batch_id, "new_batch_id"),
         {:ok, batch} <- fetch_batch_for_correction(old_id),
         :ok <- ensure_batch_id_available(new_id, batch) do
      # Rename the batch and fix up session filters in one transaction: quiz sessions are
      # scoped by the batch_id *string* stored in session.meta_data["batch_id"], so renaming
      # only the batch row would silently drop those sessions for the corrected batch.
      Repo.transaction(fn ->
        case update_batch(batch, %{"batch_id" => new_id}) do
          {:ok, updated_batch} ->
            rewrite_session_batch_id_metadata(old_id, new_id)
            updated_batch

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  # session.meta_data["batch_id"] holds a comma-separated list of batch_ids (see
  # Dbservice.GroupSessions.add_batch_filter/2). Replace the renamed id wherever it appears
  # in that list, preserving the order and the other entries.
  defp rewrite_session_batch_id_metadata(old_batch_id, new_batch_id) do
    Repo.query!(
      """
      UPDATE session
      SET meta_data = jsonb_set(
            meta_data,
            '{batch_id}',
            to_jsonb((
              SELECT string_agg(
                       CASE WHEN token = $1 THEN $2 ELSE token END,
                       ',' ORDER BY ord
                     )
              FROM unnest(string_to_array(trim(meta_data->>'batch_id'), ','))
                   WITH ORDINALITY AS t(token, ord)
            ))
          )
      WHERE meta_data->>'batch_id' IS NOT NULL
        AND $1 = ANY(string_to_array(trim(meta_data->>'batch_id'), ','))
      """,
      [old_batch_id, new_batch_id]
    )

    :ok
  end

  defp require_batch_id(value, field) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, "#{field} is required"}
      trimmed -> {:ok, trimmed}
    end
  end

  defp require_batch_id(_value, field), do: {:error, "#{field} is required"}

  # `batch_id` has no unique constraint, so tolerate (and reject) duplicates rather than
  # letting `Repo.get_by` raise.
  defp fetch_batch_for_correction(batch_id) do
    case Repo.all(from(b in Batch, where: b.batch_id == ^batch_id)) do
      [] ->
        {:error, "No batch found with batch_id '#{batch_id}'"}

      [batch] ->
        {:ok, batch}

      _multiple ->
        {:error, "Multiple batches share batch_id '#{batch_id}'; correct them manually"}
    end
  end

  defp ensure_batch_id_available(new_batch_id, %Batch{} = batch) do
    if Repo.exists?(from(b in Batch, where: b.batch_id == ^new_batch_id and b.id != ^batch.id)) do
      {:error, "batch_id '#{new_batch_id}' already exists for another batch"}
    else
      :ok
    end
  end

  @doc """
  Deletes a batch.
  ## Examples
      iex> delete_batch(batch)
      {:ok, %Batch{}}
      iex> delete_batch(batch)
      {:error, %Ecto.Changeset{}}
  """
  def delete_batch(%Batch{} = batch) do
    Repo.delete(batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking batch changes.
  ## Examples
      iex> change_batch(batch)
      %Ecto.Changeset{data: %Batch{}}
  """
  def change_batch(%Batch{} = batch, attrs \\ %{}) do
    Batch.changeset(batch, attrs)
  end
end
