defmodule DbserviceWeb.TeacherFeedbackSummaryControllerTest do
  use DbserviceWeb.ConnCase

  alias Dbservice.Repo

  @summary %{
    "highlights" => ["Explains concepts clearly"],
    "concerns" => [%{"text" => "Starts class late", "serious" => false, "recurring" => true}]
  }

  defp insert_feedback(session_pk, attrs \\ %{}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    row =
      Map.merge(
        %{
          setup_run_id: Ecto.UUID.bingenerate(),
          cycle_label: "Sep 2026",
          school_code: "59324",
          teacher_name: "Indrani Khan",
          teacher_order: 1,
          session_pk: session_pk,
          status: "created",
          created_by: "pm@avantifellows.org",
          inserted_at: now,
          updated_at: now
        },
        attrs
      )

    Repo.insert_all("lms_teacher_feedback", [row])
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "saves a summary and lists it by session", %{conn: conn} do
    insert_feedback(101)
    insert_feedback(102)

    conn =
      put(conn, ~p"/api/teacher-feedback-summary/101", %{
        "summary" => @summary,
        "summary_prompt_version" => "v1",
        "summary_fingerprint" => String.duplicate("a", 64)
      })

    assert json_response(conn, 200) == %{"updated" => 1}

    conn = get(conn, ~p"/api/teacher-feedback-summary?session_pks=101,102")
    rows = conn |> json_response(200) |> Enum.sort_by(& &1["session_pk"])

    assert [%{"session_pk" => 101} = saved, %{"session_pk" => 102} = empty] = rows
    assert saved["summary"] == @summary
    assert saved["summary_prompt_version"] == "v1"
    assert saved["summary_generated_at"]
    assert empty["summary"] == nil
  end

  test "ignores deleted rows and 404s a session with no active row", %{conn: conn} do
    insert_feedback(103, %{deleted_at: ~N[2026-09-01 00:00:00]})

    conn =
      put(conn, ~p"/api/teacher-feedback-summary/103", %{
        "summary" => @summary,
        "summary_prompt_version" => "v1",
        "summary_fingerprint" => "abc"
      })

    assert json_response(conn, 404)

    assert get(conn, ~p"/api/teacher-feedback-summary?session_pks=103") |> json_response(200) ==
             []
  end

  test "rejects malformed requests", %{conn: conn} do
    insert_feedback(104)

    assert put(conn, ~p"/api/teacher-feedback-summary/104", %{
             "summary" => "not an object",
             "summary_prompt_version" => "v1",
             "summary_fingerprint" => "abc"
           })
           |> json_response(400)

    assert put(conn, ~p"/api/teacher-feedback-summary/104", %{"summary" => @summary})
           |> json_response(400)

    assert put(conn, ~p"/api/teacher-feedback-summary/abc", %{}) |> json_response(400)
    assert get(conn, ~p"/api/teacher-feedback-summary?session_pks=1,x") |> json_response(400)
    assert get(conn, ~p"/api/teacher-feedback-summary") |> json_response(400)
  end
end
