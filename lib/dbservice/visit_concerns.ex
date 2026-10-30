defmodule Dbservice.VisitConcerns do
  @moduledoc """
  Machine APIs for the etl-next Visit Concern flow (LMS #470).

  The `lms_visit_*` tables have no Ecto schemas: af_lms reads them directly and
  writes the human events, so they are queried by table name. Queries that carry
  Visit free text, record text or snippets run with `log: false`.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.VisitConcerns.Extraction

  @chunk_size 200

  @doc "True for an id that fits a Postgres `bigint` primary key: 1..2^63-1."
  defguard is_id(value)
           when is_integer(value) and value >= 1 and value <= 9_223_372_036_854_775_807

  @doc """
  Completed, non-deleted Visits that still need summarising, oldest first.

  Options: `prompt_version`, `limit`, `cursor` (`{visit_date, visit_id}` or nil),
  `visit_ids` (list or nil) and `force`. Returns
  `%{visits, records_by_school, next_cursor}`.
  """
  def list_pending_visits(opts) do
    {visits, more?} = scan_pending(opts, opts.cursor, opts.limit + 1, [])
    school_codes = visits |> Enum.map(& &1.school_code) |> Enum.uniq()

    records =
      school_codes
      |> records_query()
      |> Repo.all(log: false)
      |> Enum.group_by(& &1.school_code, &Map.delete(&1, :school_code))

    %{
      visits:
        Enum.map(
          visits,
          &Map.take(&1, [:visit_id, :school_code, :visit_date, :fingerprint, :items])
        ),
      records_by_school: Map.new(school_codes, &{&1, Map.get(records, &1, [])}),
      next_cursor: next_cursor(visits, more?)
    }
  end

  @doc """
  Stores one Visit's summary in a single transaction: replaces the Visit's
  mentions, creates the `new` records, upserts its Visit Note Summary and
  auto-reopens the mentioned Concerns resolved before the Visit's IST date.

  `attrs` has string keys `fingerprint`, `prompt_version` and `points`. Returns
  `{:ok, records_for_school(school_code)}`, `{:error, :not_found}` for a missing,
  soft-deleted or not-completed Visit, or `{:error, message}` for a bad body.
  """
  def put_visit_summary(visit_id, attrs) do
    with {:ok, summary} <- validate_summary(attrs) do
      Repo.transaction(fn -> store_summary!(visit_id, summary) end)
    end
  end

  defp store_summary!(visit_id, summary) do
    %{school_code: school_code, visit_date: visit_date} = lock_visit!(visit_id)
    check_existing_records!(summary.points, school_code)
    lock_concerns!(visit_id, summary.points)

    # Taken after the locks, so an auto-reopen is never stamped earlier than a
    # resolution committed while this transaction waited for them.
    now = db_now()

    {_count, previous_ids} =
      from(m in "lms_visit_concern_mentions",
        where: m.visit_id == ^visit_id,
        select: m.concern_id
      )
      |> Repo.delete_all()

    mentions =
      summary.points
      |> resolve_points(previous_records(previous_ids, school_code), school_code, now)
      |> Enum.uniq_by(fn {concern_id, _snippet} -> concern_id end)
      |> Enum.map(fn {concern_id, snippet} ->
        %{concern_id: concern_id, visit_id: visit_id, snippet: snippet, inserted_at: now}
      end)

    Repo.insert_all("lms_visit_concern_mentions", mentions, log: false)

    Repo.insert_all(
      "lms_visit_note_summaries",
      [
        %{
          visit_id: visit_id,
          fingerprint: summary.fingerprint,
          prompt_version: summary.prompt_version,
          summarised_at: now
        }
      ],
      on_conflict: {:replace, [:fingerprint, :prompt_version, :summarised_at]},
      conflict_target: :visit_id
    )

    mentions
    |> Enum.map(& &1.concern_id)
    |> auto_reopen!(visit_id, visit_date, now)

    records_for_school(school_code)
  end

  # The DB clock, not the app's, read when called (clock_timestamp(), not the
  # transaction start that NOW() gives) and rounded to the second as a
  # `timestamp(0)` write rounds it. af_lms stamps its events the same way after
  # its row lock, so stamps from both sides follow lock (commit) order.
  defp db_now do
    %{rows: [[now]]} =
      Repo.query!("SELECT (clock_timestamp() AT TIME ZONE 'UTC')::timestamp(0)")

    now
  end

  defp lock_visit!(visit_id) do
    visit =
      from(v in "lms_pm_school_visits",
        where: v.id == ^visit_id,
        lock: "FOR UPDATE",
        select: %{
          school_code: v.school_code,
          visit_date: v.visit_date,
          status: v.status,
          deleted_at: v.deleted_at
        }
      )
      |> Repo.one()

    case visit do
      %{status: "completed", deleted_at: nil} -> visit
      _ -> Repo.rollback(:not_found)
    end
  end

  # Lock order: the Visit row (`lock_visit!/1`), then this. Locks FOR UPDATE, in
  # one statement and ascending id order, every Concern this PUT can mention:
  # the payload's `existing_id`s and the Concerns the Visit mentioned before
  # (a `new` point may reuse one of those). It runs before any mention is deleted
  # or inserted because a mention insert's FK check takes FOR KEY SHARE on its
  # Concern: two PUTs at one School that both held KEY SHARE on a Concern and
  # then asked for FOR UPDATE would wait on each other and deadlock. The
  # previous mentions are read in a subquery; the Visit lock keeps them fixed
  # until they are deleted. Records this PUT creates are invisible to other
  # transactions until commit, and Highlights are never locked.
  defp lock_concerns!(visit_id, points) do
    existing_ids = for %{existing_id: id} <- points, do: id

    previous_ids =
      from(m in "lms_visit_concern_mentions",
        where: m.visit_id == ^visit_id,
        select: m.concern_id
      )

    from(c in "lms_visit_concerns",
      where: c.kind == "concern" and (c.id in ^existing_ids or c.id in subquery(previous_ids)),
      order_by: c.id,
      lock: "FOR UPDATE",
      select: c.id
    )
    |> Repo.all()
  end

  # Every mentioned Concern is already locked by `lock_concerns!/2` or was
  # created by this transaction, so no resolution can land between these reads
  # and the reopen, and the reads see any resolution committed while the lock
  # waited.
  defp auto_reopen!(concern_ids, visit_id, visit_date, now) do
    resolved_ids =
      from(c in "lms_visit_concerns",
        where: c.id in ^concern_ids and c.kind == "concern" and c.status == "resolved",
        select: c.id
      )
      |> Repo.all()

    reopen_ids =
      for {id, resolved_on} <- latest_resolved_on(resolved_ids),
          Date.compare(visit_date, resolved_on) == :gt,
          do: id

    from(c in "lms_visit_concerns", where: c.id in ^reopen_ids)
    |> Repo.update_all(set: [status: "open", updated_at: now])

    Repo.insert_all(
      "lms_visit_concern_events",
      Enum.map(
        reopen_ids,
        &%{concern_id: &1, kind: "auto_reopened", visit_id: visit_id, inserted_at: now}
      )
    )
  end

  # `{concern_id, IST date of its latest resolved event}`; Concerns with no
  # `resolved` event are absent.
  defp latest_resolved_on([]), do: []

  defp latest_resolved_on(concern_ids) do
    from(e in "lms_visit_concern_events",
      where: e.concern_id in ^concern_ids and e.kind == "resolved",
      distinct: e.concern_id,
      order_by: [e.concern_id, desc: e.inserted_at, desc: e.id],
      select:
        {e.concern_id,
         fragment("(? AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date", e.inserted_at)}
    )
    |> Repo.all()
  end

  defp check_existing_records!(points, school_code) do
    ids = for %{existing_id: id} <- points, do: id

    records =
      from(c in "lms_visit_concerns",
        where: c.id in ^ids,
        select: {c.id, %{school_code: c.school_code, kind: c.kind}}
      )
      |> Repo.all()
      |> Map.new()

    for %{existing_id: id, kind: kind} <- points do
      case Map.get(records, id) do
        nil -> Repo.rollback("existing_id #{id} does not exist")
        %{school_code: ^school_code, kind: ^kind} -> :ok
        %{school_code: ^school_code} -> Repo.rollback("existing_id #{id} is not a #{kind}")
        _ -> Repo.rollback("existing_id #{id} belongs to another School")
      end
    end
  end

  # `{kind, text}` => record id for this School's records the Visit mentioned
  # before its mentions were replaced, so a retried PUT reuses them.
  defp previous_records(previous_ids, school_code) do
    from(c in "lms_visit_concerns",
      where: c.id in ^previous_ids and c.school_code == ^school_code,
      order_by: [desc: c.id],
      select: {{c.kind, c.text}, c.id}
    )
    |> Repo.all(log: false)
    |> Map.new()
  end

  defp resolve_points(points, known, school_code, now) do
    {resolved, _known} =
      Enum.map_reduce(points, known, fn
        %{existing_id: id, snippet: snippet}, known ->
          {{id, snippet}, known}

        %{new: {kind, text}, snippet: snippet}, known ->
          id =
            Map.get_lazy(known, {kind, text}, fn ->
              insert_record!(school_code, kind, text, now)
            end)

          {{id, snippet}, Map.put(known, {kind, text}, id)}
      end)

    resolved
  end

  defp insert_record!(school_code, kind, text, now) do
    {1, [%{id: id}]} =
      Repo.insert_all(
        "lms_visit_concerns",
        [
          %{
            school_code: school_code,
            kind: kind,
            text: text,
            status: if(kind == "concern", do: "open"),
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id],
        log: false
      )

    id
  end

  defp validate_summary(attrs) do
    with {:ok, fingerprint} <- fetch_fingerprint(attrs),
         {:ok, prompt_version} <- fetch_prompt_version(attrs),
         {:ok, points} <- fetch_points(attrs) do
      {:ok, %{fingerprint: fingerprint, prompt_version: prompt_version, points: points}}
    end
  end

  defp fetch_fingerprint(attrs) do
    case Map.get(attrs, "fingerprint") do
      value when is_binary(value) ->
        if value =~ ~r/\A[0-9a-f]{64}\z/,
          do: {:ok, value},
          else: {:error, "fingerprint must be 64 lowercase hex characters"}

      _ ->
        {:error, "fingerprint must be 64 lowercase hex characters"}
    end
  end

  @doc """
  The trimmed `prompt_version` from `map` (string keys), 1..50 characters. GET
  pending-visits and PUT visit-summary share it so they accept the same values.
  """
  def fetch_prompt_version(map), do: fetch_text(map, "prompt_version", 50)

  # Trimmed, then 1..max Unicode code points, as Postgres `char_length` counts:
  # `String.length/1` counts graphemes, and one grapheme can hold any number of
  # combining marks. A Postgres text value cannot hold NUL, so that is a 400 here
  # rather than a database error. Plug has already rejected invalid UTF-8.
  defp fetch_text(map, key, max) do
    with value when is_binary(value) <- Map.get(map, key),
         {:nul, false} <- {:nul, String.contains?(value, <<0>>)},
         trimmed = String.trim(value),
         length when length >= 1 and length <= max <- length(String.codepoints(trimmed)) do
      {:ok, trimmed}
    else
      {:nul, true} -> {:error, "#{key} must not contain NUL characters"}
      _ -> {:error, "#{key} must be a non-empty string of at most #{max} characters"}
    end
  end

  defp fetch_points(attrs) do
    case Map.get(attrs, "points") do
      points when is_list(points) and length(points) <= 100 ->
        points
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {point, index}, {:ok, acc} ->
          case validate_point(point) do
            {:ok, point} -> {:cont, {:ok, [point | acc]}}
            {:error, message} -> {:halt, {:error, "points[#{index}]: #{message}"}}
          end
        end)
        |> case do
          {:ok, points} -> {:ok, Enum.reverse(points)}
          error -> error
        end

      _ ->
        {:error, "points must be a list of at most 100 points"}
    end
  end

  defp validate_point(%{"existing_id" => _, "new" => _}),
    do: {:error, "a point needs exactly one of existing_id or new"}

  defp validate_point(%{"existing_id" => id} = point) when is_id(id) do
    with {:ok, kind} <- fetch_kind(point),
         {:ok, snippet} <- fetch_text(point, "snippet", 300) do
      {:ok, %{existing_id: id, kind: kind, snippet: snippet}}
    end
  end

  defp validate_point(%{"existing_id" => _}),
    do: {:error, "existing_id must be a positive integer"}

  defp validate_point(%{"new" => new} = point) when is_map(new) do
    with {:ok, kind} <- fetch_kind(new),
         {:ok, text} <- fetch_text(new, "text", 500),
         {:ok, snippet} <- fetch_text(point, "snippet", 300) do
      {:ok, %{new: {kind, text}, snippet: snippet}}
    end
  end

  defp validate_point(_point),
    do: {:error, "a point needs exactly one of existing_id or new: {kind, text}"}

  defp fetch_kind(map) do
    case Map.get(map, "kind") do
      kind when kind in ["concern", "highlight"] -> {:ok, kind}
      _ -> {:error, "kind must be concern or highlight"}
    end
  end

  @doc """
  Every record at the School (open, resolved and hidden), ordered by id, as
  `%{id, kind, text, status, latest_resolved_on}`. `latest_resolved_on` is the
  IST date of the Concern's latest `resolved` event, nil for Highlights and
  never-resolved Concerns.
  """
  def records_for_school(school_code) do
    [school_code]
    |> records_query()
    |> Repo.all(log: false)
    |> Enum.map(&Map.delete(&1, :school_code))
  end

  defp records_query(school_codes) do
    from(c in "lms_visit_concerns",
      where: c.school_code in ^school_codes,
      order_by: c.id,
      select: %{
        id: c.id,
        school_code: c.school_code,
        kind: c.kind,
        text: c.text,
        status: c.status,
        latest_resolved_on:
          fragment(
            """
            CASE WHEN ? = 'concern' THEN (
              SELECT (e.inserted_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date
              FROM lms_visit_concern_events e
              WHERE e.concern_id = ? AND e.kind = 'resolved'
              ORDER BY e.inserted_at DESC, e.id DESC
              LIMIT 1
            ) END
            """,
            c.kind,
            c.id
          )
      }
    )
  end

  defp scan_pending(opts, cursor, wanted, acc) do
    candidates = candidate_visits(opts, cursor)
    pending = acc ++ Enum.filter(with_items(candidates), &pending?(&1, opts))

    cond do
      length(pending) >= wanted ->
        {Enum.take(pending, wanted - 1), true}

      length(candidates) < @chunk_size ->
        {pending, false}

      true ->
        last = List.last(candidates)
        scan_pending(opts, {last.visit_date, last.id}, wanted, pending)
    end
  end

  defp candidate_visits(opts, cursor) do
    from(v in "lms_pm_school_visits",
      where: v.status == "completed" and is_nil(v.deleted_at),
      order_by: [v.visit_date, v.id],
      limit: @chunk_size,
      select: %{id: v.id, school_code: v.school_code, visit_date: v.visit_date}
    )
    |> only_visits(opts.visit_ids)
    |> after_cursor(cursor)
    |> Repo.all()
  end

  defp only_visits(query, nil), do: query
  defp only_visits(query, visit_ids), do: where(query, [v], v.id in ^visit_ids)

  defp after_cursor(query, nil), do: query

  defp after_cursor(query, {visit_date, visit_id}) do
    where(
      query,
      [v],
      fragment("(?, ?) > (?, ?)", v.visit_date, v.id, type(^visit_date, :date), ^visit_id)
    )
  end

  defp with_items([]), do: []

  defp with_items(visits) do
    ids = Enum.map(visits, & &1.id)

    actions =
      from(a in "lms_pm_school_visit_actions",
        where: a.visit_id in ^ids and is_nil(a.deleted_at),
        select: %{id: a.id, visit_id: a.visit_id, action_type: a.action_type, data: a.data}
      )
      |> Repo.all(log: false)
      |> Enum.group_by(& &1.visit_id)

    teacher_subjects =
      actions
      |> Map.values()
      |> Enum.concat()
      |> Extraction.teacher_ids()
      |> teacher_subjects()

    summaries =
      from(s in "lms_visit_note_summaries",
        where: s.visit_id in ^ids,
        select: {s.visit_id, %{fingerprint: s.fingerprint, prompt_version: s.prompt_version}}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(visits, fn visit ->
      items = Extraction.items(Map.get(actions, visit.id, []), teacher_subjects)

      Map.merge(visit, %{
        visit_id: visit.id,
        items: items,
        fingerprint: Extraction.fingerprint(items),
        summary: Map.get(summaries, visit.id)
      })
    end)
  end

  # `individual_af_teacher_interaction` teacher ids are LMS `user_permission`
  # ids (the LMS teacher picker lists those), not `teacher` ids. A subject is
  # used only on the explicit `user_permission.user_id` link to exactly one
  # `teacher` row whose subject has an English name: the LMS's email fallback
  # is fragile, and a person with several teacher rows has no single subject.
  # Every other id gets no subject. Names are never read.
  defp teacher_subjects([]), do: %{}

  defp teacher_subjects(permission_ids) do
    from(up in "user_permission",
      join: t in "teacher",
      on: t.user_id == up.user_id,
      left_join: s in "subject",
      on: s.id == t.subject_id,
      where: up.id in ^permission_ids,
      select: {up.id, s.name}
    )
    |> Repo.all()
    |> Enum.group_by(fn {id, _name} -> id end, fn {_id, name} -> name end)
    |> Enum.flat_map(fn
      {id, [names]} ->
        case english_subject(names) do
          nil -> []
          subject -> [{id, subject}]
        end

      {_id, _several} ->
        []
    end)
    |> Map.new()
  end

  # `subject.name` is a list of `%{"lang_code", "subject"}` translations.
  defp english_subject(names) when is_list(names) do
    Enum.find_value(names, fn
      %{"lang_code" => "en", "subject" => subject} -> Extraction.subject_text(subject)
      _ -> nil
    end)
  end

  defp english_subject(_names), do: nil

  defp pending?(_visit, %{force: true}), do: true
  defp pending?(%{summary: nil}, _opts), do: true

  defp pending?(%{summary: summary, fingerprint: fingerprint}, opts) do
    summary.fingerprint != fingerprint or summary.prompt_version != opts.prompt_version
  end

  defp next_cursor(_visits, false), do: nil

  defp next_cursor(visits, true) do
    last = List.last(visits)
    %{after_visit_date: last.visit_date, after_id: last.id}
  end
end
