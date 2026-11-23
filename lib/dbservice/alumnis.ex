defmodule Dbservice.Alumnis do
  @moduledoc """
  The Alumnis context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Alumnis.Alumni
  alias Dbservice.Alumnis.AlumniJourney

  @doc """
  Returns the list of alumni.

  ## Examples

      iex> list_alumni()
      [%Alumni{}, ...]

  """
  def list_alumni do
    Repo.all(Alumni)
  end

  @doc """
  Gets a single alumni.

  Returns `nil` if the Alumni does not exist.

  ## Examples

      iex> get_alumni(123)
      %Alumni{}

      iex> get_alumni(456)
      nil

  """
  def get_alumni(id), do: Repo.get(Alumni, id)

  @doc """
  Gets an alumni by student_id.

  Returns `nil` if the Alumni does not exist.

  ## Examples

      iex> get_alumni_by_student_id(123)
      %Alumni{}

      iex> get_alumni_by_student_id(456)
      nil

  """
  def get_alumni_by_student_id(student_id) do
    Repo.get_by(Alumni, student_id: student_id)
  end

  @doc """
  Creates an alumni.

  ## Examples

      iex> create_alumni(%{field: value})
      {:ok, %Alumni{}}

      iex> create_alumni(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_alumni(attrs \\ %{}) do
    %Alumni{}
    |> Alumni.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an alumni.

  ## Examples

      iex> update_alumni(alumni, %{field: new_value})
      {:ok, %Alumni{}}

      iex> update_alumni(alumni, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_alumni(%Alumni{} = alumni, attrs) do
    alumni
    |> Alumni.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an alumni.

  ## Examples

      iex> delete_alumni(alumni)
      {:ok, %Alumni{}}

      iex> delete_alumni(alumni)
      {:error, %Ecto.Changeset{}}

  """
  def delete_alumni(%Alumni{} = alumni) do
    alumni
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.foreign_key_constraint(:id,
      name: :alumni_journey_alumni_id_fkey,
      message: "has follow-up history and cannot be deleted"
    )
    |> Repo.delete()
  end

  @doc """
  Records one follow-up with an alumnus.

  In one transaction: applies the answers in `attrs["data"]` to the `alumni`
  row (so `/api/alumni` keeps returning the latest state), then appends an
  `alumni_journey` row holding the full snapshot of answers after the update.

  - `data` may only contain alumni answer fields; any other key is rejected so a
    typo cannot silently drop an answer. `student_id` cannot be changed here.
  - A blank (`nil`, or a string of only whitespace) never erases a recorded
    answer; it is ignored.
  - The top-level `contact_status` (the call's outcome) is also applied to
    `alumni.contact_status`; one that contradicts `data.contact_status` is rejected.
  - `reported_on` may not be earlier than the alumnus's latest journey row: the
    snapshot is the alumni row as it is now, so a back-dated row would file
    today's answers under an older date.
  - `changed_fields` is computed here, against the latest journey row (or
    against nothing, for an alumnus's first row), not trusted from the caller.
  """
  def record_journey(%Alumni{id: alumni_id}, attrs) when is_map(attrs) do
    with {:ok, answers} <- journey_answers(Map.get(attrs, "data", %{})),
         {:ok, answers} <- put_contact_status(answers, Map.get(attrs, "contact_status")) do
      Repo.transaction(fn ->
        with %Alumni{} = alumni <- lock_alumni(alumni_id),
             %Ecto.Changeset{valid?: true} = changeset <- journey_changeset(attrs, alumni_id),
             {latest_on, previous} = latest_journey(alumni_id),
             :ok <- not_back_dated(Ecto.Changeset.get_field(changeset, :reported_on), latest_on),
             {:ok, alumni} <- update_alumni(alumni, answers),
             snapshot = answers_snapshot(alumni),
             {:ok, journey} <-
               changeset
               |> Ecto.Changeset.put_change(:data, snapshot)
               |> Ecto.Changeset.put_change(:changed_fields, changed_fields(previous, snapshot))
               |> Repo.insert() do
          journey
        else
          nil -> Repo.rollback(:not_found)
          {:error, error} -> Repo.rollback(error)
          %Ecto.Changeset{} = invalid -> Repo.rollback(%{invalid | action: :insert})
        end
      end)
    end
  end

  # Re-read under lock: the alumni may have been deleted since the caller loaded it.
  defp lock_alumni(alumni_id) do
    Repo.one(from(a in Alumni, where: a.id == ^alumni_id, lock: "FOR UPDATE"))
  end

  # `data` is a placeholder until the snapshot is taken after the alumni update.
  defp journey_changeset(attrs, alumni_id) do
    attrs
    |> Map.take(~w(reported_on source contact_status actor_email actor_role notes))
    |> Map.merge(%{"alumni_id" => alumni_id, "data" => %{}})
    |> then(&AlumniJourney.changeset(%AlumniJourney{}, &1))
  end

  @answer_keys Enum.map(Alumni.answer_fields(), &Atom.to_string/1)

  defp journey_answers(data) when is_map(data) do
    case Map.keys(data) -- @answer_keys do
      [] ->
        {:ok, Map.reject(data, fn {_key, value} -> blank?(value) end)}

      unknown ->
        {:error,
         "data has fields that are not alumni answers: #{Enum.join(Enum.sort(unknown), ", ")}"}
    end
  end

  defp journey_answers(_data), do: {:error, "data must be an object"}

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp put_contact_status(answers, outcome) do
    cond do
      blank?(outcome) ->
        {:ok, answers}

      not Map.has_key?(answers, "contact_status") ->
        {:ok, Map.put(answers, "contact_status", outcome)}

      answers["contact_status"] == outcome ->
        {:ok, answers}

      true ->
        {:error, "contact_status and data.contact_status disagree"}
    end
  end

  defp not_back_dated(_reported_on, nil), do: :ok

  defp not_back_dated(reported_on, latest_on) do
    if Date.compare(reported_on, latest_on) == :lt do
      {:error, "reported_on is earlier than the latest follow-up (#{latest_on})"}
    else
      :ok
    end
  end

  # Round-tripped through JSON so it compares equal to what jsonb hands back.
  defp answers_snapshot(%Alumni{} = alumni) do
    alumni |> Map.take(Alumni.answer_fields()) |> Jason.encode!() |> Jason.decode!()
  end

  defp latest_journey(alumni_id) do
    from(j in AlumniJourney,
      where: j.alumni_id == ^alumni_id,
      order_by: [desc: j.reported_on, desc: j.id],
      limit: 1,
      select: {j.reported_on, j.data}
    )
    |> Repo.one()
    |> Kernel.||({nil, %{}})
  end

  defp changed_fields(previous, snapshot) do
    for {field, value} <- snapshot, Map.get(previous, field) != value, do: field
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking alumni changes.

  ## Examples

      iex> change_alumni(alumni)
      %Ecto.Changeset{data: %Alumni{}}

  """
  def change_alumni(%Alumni{} = alumni, attrs \\ %{}) do
    Alumni.changeset(alumni, attrs)
  end
end
