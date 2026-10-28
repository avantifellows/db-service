defmodule Dbservice.VisitConcernsFixtures do
  @moduledoc """
  Test helpers for the Visit Concern APIs (LMS #470): seeding Visits, their
  actions and Visit Note Summaries, and reading GET pending-visits.
  """

  import Phoenix.ConnTest
  alias Dbservice.Repo

  @endpoint DbserviceWeb.Endpoint

  @doc """
  Inserts a Visit and its actions; returns the Visit id. Each action is a map
  with `action_type` and `data`, plus optional `status` and `deleted_at`.
  """
  def insert_visit(attrs, actions \\ []) do
    now = ~N[2026-10-20 06:00:00]

    visit =
      Map.merge(
        %{
          school_code: "70705",
          pm_email: "pm@avantifellows.org",
          visit_date: ~D[2026-10-10],
          status: "completed",
          completed_at: now,
          deleted_at: nil,
          inserted_at: now,
          updated_at: now
        },
        attrs
      )

    {1, [%{id: visit_id}]} = Repo.insert_all("lms_pm_school_visits", [visit], returning: [:id])

    Enum.each(actions, &insert_action(visit_id, &1))
    visit_id
  end

  defp insert_action(visit_id, action) do
    now = ~N[2026-10-20 06:00:00]
    status = Map.get(action, :status, "completed")

    {started_at, ended_at} =
      case status do
        "pending" -> {nil, nil}
        "in_progress" -> {now, nil}
        "completed" -> {now, now}
      end

    Repo.insert_all("lms_pm_school_visit_actions", [
      %{
        visit_id: visit_id,
        action_type: action.action_type,
        data: action.data,
        status: status,
        started_at: started_at,
        ended_at: ended_at,
        deleted_at: Map.get(action, :deleted_at),
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  def insert_summary(visit_id, fingerprint, prompt_version) do
    Repo.insert_all("lms_visit_note_summaries", [
      %{
        visit_id: visit_id,
        fingerprint: fingerprint,
        prompt_version: prompt_version,
        summarised_at: ~N[2026-10-20 07:00:00]
      }
    ])
  end

  def set_action_data(visit_id, data) do
    Repo.query!("UPDATE lms_pm_school_visit_actions SET data = $1 WHERE visit_id = $2", [
      data,
      visit_id
    ])
  end

  def item(action_type, label, text),
    do: %{"action_type" => action_type, "label" => label, "text" => text}

  def pending_visits(conn, query) do
    conn |> get("/api/visit-concerns/pending-visits?" <> query) |> json_response(200)
  end

  def pending_ids(conn, query) do
    conn |> pending_visits(query) |> Map.fetch!("visits") |> Enum.map(& &1["visit_id"])
  end
end
