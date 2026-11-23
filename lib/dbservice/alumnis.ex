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

  # Every write to an alumni's answers leaves a journey row behind, so the
  # history is complete whichever path made the change. These defaults
  # describe a write through the generic /api/alumni routes.
  @api_create %{"source" => "initial", "actor_role" => "api"}
  @api_update %{"source" => "correction", "actor_role" => "api"}

  @doc """
  Creates an alumni, and a journey row for the answers it starts with.

  `journey` describes who or what made the write (`source`, `actor_role`,
  `notes`). No journey row is written when the alumni has no answers yet.
  """
  def create_alumni(attrs \\ %{}, journey \\ @api_create) do
    Repo.transaction(fn ->
      with {:ok, alumni} <- %Alumni{} |> Alumni.changeset(attrs) |> Repo.insert(),
           {:ok, _journey} <- append_if_changed(alumni, journey, Date.utc_today(), %{}) do
        alumni
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Updates an alumni, and records a journey row if any answer changed.

  An alumni with no history yet first gets an `initial` row holding its
  answers as they were, so the update never destroys the starting copy.
  """
  def update_alumni(%Alumni{id: alumni_id}, attrs, journey \\ @api_update) do
    Repo.transaction(fn ->
      with %Alumni{} = alumni <- lock_alumni(alumni_id),
           reported_on = system_reported_on(alumni_id),
           {:ok, previous} <- history_before(alumni, reported_on),
           {:ok, alumni} <- alumni |> Alumni.changeset(attrs) |> Repo.update(),
           {:ok, _journey} <- append_if_changed(alumni, journey, reported_on, previous) do
        alumni
      else
        nil -> Repo.rollback(:not_found)
        {:error, error} -> Repo.rollback(error)
      end
    end)
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
    answer; it is ignored. The exception is `source: "correction"`, where a
    blank clears the answer, so an earlier version can be restored exactly.
  - The top-level `contact_status` (the call's outcome) is also applied to
    `alumni.contact_status`; one that contradicts `data.contact_status` is rejected.
  - `reported_on` may not be earlier than the alumnus's latest journey row: the
    snapshot is the alumni row as it is now, so a back-dated row would file
    today's answers under an older date.
  - An alumnus with no history yet first gets an `initial` row with its answers
    as they were before this follow-up.
  - `changed_fields` is computed here, against the latest journey row (or
    against nothing, for an alumnus's first row), not trusted from the caller.
  """
  def record_journey(%Alumni{id: alumni_id}, attrs) when is_map(attrs) do
    clear_blanks? = Map.get(attrs, "source") == "correction"

    with {:ok, answers} <- journey_answers(Map.get(attrs, "data", %{}), clear_blanks?),
         {:ok, answers} <- put_contact_status(answers, Map.get(attrs, "contact_status")) do
      Repo.transaction(fn ->
        with %Alumni{} = alumni <- lock_alumni(alumni_id),
             %Ecto.Changeset{valid?: true} = changeset <- journey_changeset(attrs, alumni_id),
             reported_on = Ecto.Changeset.get_field(changeset, :reported_on),
             {latest_on, _data} = latest_journey(alumni_id),
             :ok <- not_back_dated(reported_on, latest_on),
             {:ok, previous} <- history_before(alumni, reported_on),
             {:ok, alumni} <- alumni |> Alumni.changeset(answers) |> Repo.update(),
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

  # The snapshot the next row is compared against. An alumni with no history
  # gets an `initial` row first, holding its answers as they are before this
  # write; it is dated no later than the write itself.
  defp history_before(%Alumni{} = alumni, reported_on) do
    case latest_journey(alumni.id) do
      {nil, _none} ->
        snapshot = answers_snapshot(alumni)

        if Enum.all?(snapshot, fn {_field, value} -> is_nil(value) end) do
          {:ok, %{}}
        else
          on = Enum.min([NaiveDateTime.to_date(alumni.updated_at), reported_on], Date)

          meta = %{
            "source" => "initial",
            "actor_role" => "system",
            "notes" => "Answers as they were before the first recorded change"
          }

          with {:ok, _journey} <- insert_system_journey(alumni.id, meta, on, snapshot, %{}) do
            {:ok, snapshot}
          end
        end

      {_latest_on, data} ->
        {:ok, data}
    end
  end

  defp append_if_changed(%Alumni{} = alumni, meta, reported_on, previous) do
    snapshot = answers_snapshot(alumni)

    if changed_fields(previous, snapshot) == [] do
      {:ok, nil}
    else
      insert_system_journey(alumni.id, meta, reported_on, snapshot, previous)
    end
  end

  defp insert_system_journey(alumni_id, meta, reported_on, snapshot, previous) do
    attrs =
      meta
      |> Map.take(~w(source actor_role notes))
      |> Map.merge(%{
        "alumni_id" => alumni_id,
        "reported_on" => reported_on,
        "data" => snapshot,
        "changed_fields" => changed_fields(previous, snapshot)
      })

    %AlumniJourney{} |> AlumniJourney.system_changeset(attrs) |> Repo.insert()
  end

  # Writes not tied to a call are dated today, but never before the latest
  # row, so they cannot make a later follow-up look back-dated.
  defp system_reported_on(alumni_id) do
    case latest_journey(alumni_id) do
      {nil, _none} -> Date.utc_today()
      {latest_on, _data} -> Enum.max([Date.utc_today(), latest_on], Date)
    end
  end

  @answer_keys Enum.map(Alumni.answer_fields(), &Atom.to_string/1)

  defp journey_answers(data, clear_blanks?) when is_map(data) do
    case Map.keys(data) -- @answer_keys do
      [] when clear_blanks? ->
        {:ok,
         Map.new(data, fn {key, value} -> {key, if(blank?(value), do: nil, else: value)} end)}

      [] ->
        {:ok, Map.reject(data, fn {_key, value} -> blank?(value) end)}

      unknown ->
        {:error,
         "data has fields that are not alumni answers: #{Enum.join(Enum.sort(unknown), ", ")}"}
    end
  end

  defp journey_answers(_data, _clear_blanks?), do: {:error, "data must be an object"}

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
