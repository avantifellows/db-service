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
           {:ok, _journey} <-
             append_if_changed(
               alumni,
               nil,
               journey,
               Date.utc_today(),
               %{},
               answers_snapshot(alumni)
             ) do
        alumni
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Updates an alumni, and records a journey row if any answer changed.

  A save that changes nothing writes no row at all. When an answer does
  change on an alumni with no history yet, an `initial` row holding its
  answers as they were is written first, so the starting copy is kept.
  """
  def update_alumni(%Alumni{id: alumni_id}, attrs, journey \\ @api_update) do
    Repo.transaction(fn ->
      with %Alumni{} = before <- lock_alumni(alumni_id),
           {previous, initial} = history_before(before),
           {:ok, alumni} <- before |> Alumni.changeset(attrs) |> Repo.update(),
           snapshot = answers_snapshot(alumni),
           {:ok, _journey} <-
             append_if_changed(before, initial, journey, Date.utc_today(), previous, snapshot) do
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
  - `reported_on` is when the call happened and may be back-dated; history is
    ordered by when rows were recorded (`id`), not by `reported_on`. It may not
    be after tomorrow (LMS sends Indian dates, the server runs on UTC) or before
    2000.
  - A row is always written, even when nothing changed (a notes-only call such
    as "wrong phone number" is still a follow-up).
  - An alumnus with no history yet first gets an `initial` row with its answers
    as they were before this follow-up.
  - `changed_fields` is computed here, against the latest recorded row (or
    against nothing, for an alumnus's first row), not trusted from the caller.
  """
  def record_journey(%Alumni{id: alumni_id}, attrs) when is_map(attrs) do
    clear_blanks? = Map.get(attrs, "source") == "correction"

    with {:ok, answers} <- journey_answers(Map.get(attrs, "data", %{}), clear_blanks?),
         {:ok, answers} <- put_contact_status(answers, Map.get(attrs, "contact_status")) do
      Repo.transaction(fn ->
        with %Alumni{} = before <- lock_alumni(alumni_id),
             %Ecto.Changeset{valid?: true} = changeset <- journey_changeset(attrs, alumni_id),
             reported_on = Ecto.Changeset.get_field(changeset, :reported_on),
             {previous, initial} = history_before(before),
             {:ok, alumni} <- before |> Alumni.changeset(answers) |> Repo.update(),
             {:ok, _initial} <- write_initial(before, initial, reported_on),
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

  # The snapshot the next row is compared against, and, for an alumni with no
  # history yet, the `initial` row still owed: its answers before this write.
  # The `initial` row is only written once the caller knows a row will follow,
  # so a save that changes nothing leaves no history behind.
  defp history_before(%Alumni{} = alumni) do
    case latest_journey(alumni.id) do
      nil ->
        snapshot = answers_snapshot(alumni)

        if Enum.all?(snapshot, fn {_field, value} -> is_nil(value) end),
          do: {%{}, nil},
          else: {snapshot, snapshot}

      data ->
        {data, nil}
    end
  end

  # Dated no later than the write that follows it.
  defp write_initial(_before, nil, _reported_on), do: {:ok, nil}

  defp write_initial(%Alumni{} = before, snapshot, reported_on) do
    on = Enum.min([NaiveDateTime.to_date(before.updated_at), reported_on], Date)

    meta = %{
      "source" => "initial",
      "actor_role" => "system",
      "notes" => "Answers as they were before the first recorded change"
    }

    insert_system_journey(before.id, meta, on, snapshot, %{})
  end

  defp append_if_changed(alumni, initial, meta, reported_on, previous, snapshot) do
    if changed_fields(previous, snapshot) == [] do
      {:ok, nil}
    else
      with {:ok, _initial} <- write_initial(alumni, initial, reported_on) do
        insert_system_journey(alumni.id, meta, reported_on, snapshot, previous)
      end
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

  # Round-tripped through JSON so it compares equal to what jsonb hands back.
  defp answers_snapshot(%Alumni{} = alumni) do
    alumni |> Map.take(Alumni.answer_fields()) |> Jason.encode!() |> Jason.decode!()
  end

  # History is ordered by when it was recorded, not by reported_on, so a
  # back-dated call is compared against what was on file when it was logged.
  defp latest_journey(alumni_id) do
    from(j in AlumniJourney,
      where: j.alumni_id == ^alumni_id,
      order_by: [desc: j.id],
      limit: 1,
      select: j.data
    )
    |> Repo.one()
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
