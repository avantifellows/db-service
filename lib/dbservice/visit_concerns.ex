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

    summaries =
      from(s in "lms_visit_note_summaries",
        where: s.visit_id in ^ids,
        select: {s.visit_id, %{fingerprint: s.fingerprint, prompt_version: s.prompt_version}}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(visits, fn visit ->
      items = Extraction.items(Map.get(actions, visit.id, []))

      Map.merge(visit, %{
        visit_id: visit.id,
        items: items,
        fingerprint: Extraction.fingerprint(items),
        summary: Map.get(summaries, visit.id)
      })
    end)
  end

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
