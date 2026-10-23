defmodule DbserviceWeb.BlendedLearningTranscriptionRequestControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import ExUnit.CaptureLog

  require Logger

  @pii_keys ~w(name first_name last_name phone email)

  test "returns a queued Transcription Request with PII-free session context", %{conn: conn} do
    scope = insert_scope("Female")
    draft_id = insert_draft!(scope)
    insert_request!(scope, draft_id, "transcription-801")

    assert conn
           |> get("/api/blended-learning/transcription-requests/transcription-801")
           |> json_response(200) == %{
             "request_key" => "transcription-801",
             "state" => "queued",
             "etl_run_id" => nil,
             "error_code" => nil,
             "draft" => %{
               "id" => draft_id,
               "state" => "transcribing",
               "occurred_on" => "2026-10-20",
               "mode" => "call",
               "spoke_with" => "student",
               "duration_minutes" => 25,
               "call_recording_s3_key" => "blended-learning/recordings/801.mp3",
               "recording_content_type" => "audio/mpeg"
             },
             "student" => %{"id" => scope.student_id, "gender" => "Female"}
           }
  end

  test "returns no name, phone or email key at any nesting level", %{conn: conn} do
    scope = insert_scope("Female")
    insert_request!(scope, insert_draft!(scope), "pii-free-801")

    response_conn = get(conn, "/api/blended-learning/transcription-requests/pii-free-801")
    body = json_response(response_conn, 200)

    assert body |> collect_keys() |> MapSet.intersection(MapSet.new(@pii_keys)) |> Enum.empty?()

    for private <- ["Asha", "Private", "@example.org", "90000008"] do
      refute response_conn.resp_body =~ private
    end
  end

  test "returns 404 for an unknown request key", %{conn: conn} do
    assert conn
           |> get("/api/blended-learning/transcription-requests/unknown-801")
           |> json_response(404) == %{
             "error" => %{
               "code" => "transcription_request_not_found",
               "message" => "Transcription Request not found"
             }
           }
  end

  test "returns a null gender when the Student's user has none", %{conn: conn} do
    scope = insert_scope(nil)
    insert_request!(scope, insert_draft!(scope), "no-gender-801")

    assert conn
           |> get("/api/blended-learning/transcription-requests/no-gender-801")
           |> json_response(200)
           |> Map.fetch!("student") == %{"id" => scope.student_id, "gender" => nil}
  end

  test "returns a null gender when the Student has no linked user", %{conn: conn} do
    scope = insert_scope("Female")
    insert_request!(scope, insert_draft!(scope), "no-user-801")
    Repo.query!("UPDATE student SET user_id = NULL WHERE id = $1", [scope.student_id])

    assert conn
           |> get("/api/blended-learning/transcription-requests/no-user-801")
           |> json_response(200)
           |> Map.fetch!("student") == %{"id" => scope.student_id, "gender" => nil}
  end

  test "requires the existing Bearer token" do
    for authorization <- [nil, "Token malformed", "Bearer wrong-environment-secret"] do
      conn =
        if authorization,
          do: put_req_header(build_conn(), "authorization", authorization),
          else: build_conn()

      assert conn
             |> get("/api/blended-learning/transcription-requests/transcription-801")
             |> response(401) == "Not Authorized"
    end
  end

  describe "POST /api/blended-learning/transcription-requests/:request_key/status" do
    test "the first running post binds the run id; replays are no-ops; completes only through /draft",
         %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "status-802")
      running = %{"etl_run_id" => "run-802", "state" => "running"}
      expected = %{"state" => "running", "etl_run_id" => "run-802", "error_code" => nil}

      assert post_status(conn, "status-802", running) == expected
      row = request_row("status-802")

      assert post_status(conn, "status-802", running) == expected
      assert request_row("status-802") == row

      assert submit_draft(conn, "status-802", draft_params(%{"etl_run_id" => "run-802"}))[
               "request_state"
             ] == "completed"

      assert [["completed", "run-802", nil, _updated_at]] = request_row("status-802")
    end

    test "failure marks a transcribing draft failed and bumps its updated_at", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "draft-failure-802")
      age_draft!(draft_id)

      post_status(conn, "draft-failure-802", %{"etl_run_id" => "run-802", "state" => "running"})

      assert post_status(conn, "draft-failure-802", %{
               "etl_run_id" => "run-802",
               "state" => "failed",
               "error_code" => "transcription_failed"
             }) == %{
               "state" => "failed",
               "etl_run_id" => "run-802",
               "error_code" => "transcription_failed"
             }

      assert draft_row(draft_id) == [["failed", false]]
    end

    test "failure leaves a discarded draft unchanged", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "discarded-802")

      Repo.query!(
        """
        UPDATE blended_learning_conversation_drafts
        SET state = 'discarded', discarded_at = '2026-10-20 09:00:00'
        WHERE id = $1
        """,
        [draft_id]
      )

      age_draft!(draft_id)
      post_status(conn, "discarded-802", %{"etl_run_id" => "run-802", "state" => "running"})
      post_status(conn, "discarded-802", %{"etl_run_id" => "run-802", "state" => "failed"})

      assert draft_row(draft_id) == [["discarded", true]]
    end

    test "failure leaves a saved draft and its Conversation unchanged", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "saved-802")
      conversation_id = save_draft!(scope, draft_id)
      age_draft!(draft_id)
      conversation = conversation_row(conversation_id)
      post_status(conn, "saved-802", %{"etl_run_id" => "run-802", "state" => "running"})
      post_status(conn, "saved-802", %{"etl_run_id" => "run-802", "state" => "failed"})

      assert draft_row(draft_id) == [["saved", true]]
      assert conversation_row(conversation_id) == conversation
    end

    test "a queued request fails with its run id before running and fails a transcribing draft",
         %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "queued-failure-802")

      assert post_status(conn, "queued-failure-802", %{
               "etl_run_id" => "run-802",
               "state" => "failed",
               "error_code" => "audio_missing"
             }) == %{
               "state" => "failed",
               "etl_run_id" => "run-802",
               "error_code" => "audio_missing"
             }

      assert [["failed"]] =
               Repo.query!(
                 "SELECT state FROM blended_learning_conversation_drafts WHERE id = $1",
                 [draft_id]
               ).rows
    end

    test "rejects a different run id once one is bound", %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "conflict-802")

      post_status(conn, "conflict-802", %{"etl_run_id" => "run-802", "state" => "running"})
      row = request_row("conflict-802")

      for state <- ["running", "failed"] do
        assert status_error(conn, "conflict-802", %{"etl_run_id" => "other-run", "state" => state}) ==
                 {409,
                  %{
                    "error" => %{
                      "code" => "etl_run_conflict",
                      "message" => "ETL run conflicts with this request"
                    }
                  }}
      end

      assert request_row("conflict-802") == row
    end

    test "/status rejects queued and completed with 422", %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "skip-802")

      for state <- ["queued", "completed"] do
        assert status_error(conn, "skip-802", %{"etl_run_id" => "run-802", "state" => state}) ==
                 {422,
                  %{
                    "error" => %{
                      "code" => "invalid_request",
                      "message" => "Status fields are missing or invalid"
                    }
                  }}
      end

      assert [["queued", nil, nil, _]] = request_row("skip-802")
    end

    test "rejects regressions from completed or failed as terminal", %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "completed-802")
      post_status(conn, "completed-802", %{"etl_run_id" => "run-802", "state" => "running"})
      submit_draft(conn, "completed-802", draft_params(%{"etl_run_id" => "run-802"}))

      other_scope = insert_scope("Female")
      insert_request!(other_scope, insert_draft!(other_scope), "failed-802")
      post_status(conn, "failed-802", %{"etl_run_id" => "run-802", "state" => "running"})
      post_status(conn, "failed-802", %{"etl_run_id" => "run-802", "state" => "failed"})

      terminal =
        {409,
         %{
           "error" => %{
             "code" => "terminal_status_conflict",
             "message" => "Transcription Request is terminal"
           }
         }}

      for {request_key, attempts} <- [
            {"completed-802", [%{"state" => "running"}, %{"state" => "failed"}]},
            {"failed-802",
             [%{"state" => "running"}, %{"state" => "failed", "error_code" => "late"}]}
          ] do
        row = request_row(request_key)

        for params <- attempts do
          assert status_error(conn, request_key, Map.put(params, "etl_run_id", "run-802")) ==
                   terminal
        end

        assert request_row(request_key) == row
      end
    end

    test "rejects missing, blank, unbounded or misplaced status fields without a write", %{
      conn: conn
    } do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "invalid-802")
      post_status(conn, "invalid-802", %{"etl_run_id" => "run-802", "state" => "running"})
      row = request_row("invalid-802")

      for params <- [
            %{"etl_run_id" => "run-802", "state" => "failed", "error_code" => ""},
            %{"etl_run_id" => "run-802", "state" => "failed", "error_code" => "   "},
            %{
              "etl_run_id" => "run-802",
              "state" => "failed",
              "error_code" => String.duplicate("x", 65)
            },
            %{"etl_run_id" => "run-802", "state" => "running", "error_code" => "oops"},
            %{"state" => "failed"},
            %{"etl_run_id" => "", "state" => "failed"},
            %{"etl_run_id" => "   ", "state" => "failed"},
            %{"etl_run_id" => String.duplicate("x", 256), "state" => "failed"},
            %{"etl_run_id" => "run-802"},
            %{"etl_run_id" => "run-802", "state" => ""},
            %{"etl_run_id" => "run-802", "state" => "cancelled"}
          ] do
        assert status_error(conn, "invalid-802", params) ==
                 {422,
                  %{
                    "error" => %{
                      "code" => "invalid_request",
                      "message" => "Status fields are missing or invalid"
                    }
                  }}
      end

      assert request_row("invalid-802") == row
    end

    test "accepts an error_code at the table's length bound", %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "bounds-802")
      post_status(conn, "bounds-802", %{"etl_run_id" => "run-802", "state" => "running"})

      assert post_status(conn, "bounds-802", %{
               "etl_run_id" => "run-802",
               "state" => "failed",
               "error_code" => String.duplicate("c", 64)
             })["state"] == "failed"
    end

    test "returns 404 for an unknown request key", %{conn: conn} do
      assert status_error(conn, "unknown-802", %{"etl_run_id" => "run-802", "state" => "running"}) ==
               {404,
                %{
                  "error" => %{
                    "code" => "transcription_request_not_found",
                    "message" => "Transcription Request not found"
                  }
                }}
    end

    test "requires the existing Bearer token" do
      for authorization <- [nil, "Token malformed", "Bearer wrong-environment-secret"] do
        conn =
          if authorization,
            do: put_req_header(build_conn(), "authorization", authorization),
            else: build_conn()

        assert conn
               |> post("/api/blended-learning/transcription-requests/status-802/status", %{
                 "etl_run_id" => "run-802",
                 "state" => "running"
               })
               |> response(401) == "Not Authorized"
      end
    end
  end

  describe "POST /api/blended-learning/transcription-requests/:request_key/draft" do
    test "applies the drafted content to a transcribing draft and completes the request", %{
      conn: conn
    } do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "submit-803")
      post_status(conn, "submit-803", %{"etl_run_id" => "run-803", "state" => "running"})
      age_draft!(draft_id)

      assert submit_draft(conn, "submit-803", draft_params()) == %{
               "request_state" => "completed",
               "draft_state" => "ready",
               "applied" => true
             }

      assert Repo.query!(
               """
               SELECT state, draft_summary, draft_action_items, draft_notes, transcript_s3_key,
                      prompt_version, model_id, updated_at > '2026-10-20 08:00:00'
               FROM blended_learning_conversation_drafts
               WHERE id = $1
               """,
               [draft_id]
             ).rows == [
               [
                 "ready",
                 "Asha is revising kinematics and wants weekly check-ins.",
                 [
                   %{"text" => "Solve 20 kinematics problems", "owner" => "student"},
                   %{"text" => "Share the revision timetable", "owner" => "mentor"}
                 ],
                 [
                   %{
                     "heading" => "Physics",
                     "points" => ["Finds graphs hard", "Wants more practice"]
                   }
                 ],
                 "blended-learning/transcripts/803.json",
                 "bl-draft-v1",
                 "model-803",
                 true
               ]
             ]

      assert [["completed", "run-803", nil, _]] = request_row("submit-803")
    end

    test "accepts empty lists", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "empty-803")
      post_status(conn, "empty-803", %{"etl_run_id" => "run-803", "state" => "running"})

      params = draft_params(%{"action_items" => [], "notes" => []})
      assert submit_draft(conn, "empty-803", params)["applied"] == true

      assert Repo.query!(
               """
               SELECT state, draft_action_items, draft_notes
               FROM blended_learning_conversation_drafts
               WHERE id = $1
               """,
               [draft_id]
             ).rows == [["ready", [], []]]
    end

    test "leaves a discarded draft unchanged and still completes the request", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "discarded-803")
      post_status(conn, "discarded-803", %{"etl_run_id" => "run-803", "state" => "running"})

      Repo.query!(
        """
        UPDATE blended_learning_conversation_drafts
        SET state = 'discarded', discarded_at = '2026-10-20 09:00:00'
        WHERE id = $1
        """,
        [draft_id]
      )

      age_draft!(draft_id)
      draft = full_draft_row(draft_id)

      assert submit_draft(conn, "discarded-803", draft_params()) == %{
               "request_state" => "completed",
               "draft_state" => "discarded",
               "applied" => false
             }

      assert full_draft_row(draft_id) == draft
      assert [["completed", "run-803", nil, _]] = request_row("discarded-803")
    end

    test "leaves a saved draft and its Conversation unchanged and still completes the request",
         %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "saved-803")
      post_status(conn, "saved-803", %{"etl_run_id" => "run-803", "state" => "running"})
      conversation_id = save_draft!(scope, draft_id)
      age_draft!(draft_id)
      draft = full_draft_row(draft_id)
      conversation = conversation_row(conversation_id)

      assert submit_draft(conn, "saved-803", draft_params()) == %{
               "request_state" => "completed",
               "draft_state" => "saved",
               "applied" => false
             }

      assert full_draft_row(draft_id) == draft
      assert conversation_row(conversation_id) == conversation
      assert [["completed", "run-803", nil, _]] = request_row("saved-803")
    end

    test "a replay by the same run after success writes nothing and reports applied false", %{
      conn: conn
    } do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "replay-803")
      post_status(conn, "replay-803", %{"etl_run_id" => "run-803", "state" => "running"})
      submit_draft(conn, "replay-803", draft_params())

      Repo.query!(
        """
        UPDATE blended_learning_conversation_drafts
        SET updated_at = '2026-10-20 08:00:00'
        WHERE id = $1
        """,
        [draft_id]
      )

      draft = full_draft_row(draft_id)
      request = request_row("replay-803")

      replay = draft_params(%{"summary" => "A different late summary", "action_items" => []})

      assert submit_draft(conn, "replay-803", replay) == %{
               "request_state" => "completed",
               "draft_state" => "ready",
               "applied" => false
             }

      assert full_draft_row(draft_id) == draft
      assert request_row("replay-803") == request

      assert Repo.query!(
               "SELECT draft_summary FROM blended_learning_conversation_drafts WHERE id = $1",
               [draft_id]
             ).rows == [["Asha is revising kinematics and wants weekly check-ins."]]
    end

    test "rejects queued, failed and differently bound requests with 409 and no write", %{
      conn: conn
    } do
      queued_scope = insert_scope("Female")
      queued_draft = insert_draft!(queued_scope)
      insert_request!(queued_scope, queued_draft, "queued-803")

      failed_scope = insert_scope("Female")
      failed_draft = insert_draft!(failed_scope)
      insert_request!(failed_scope, failed_draft, "failed-803")
      post_status(conn, "failed-803", %{"etl_run_id" => "run-803", "state" => "running"})
      post_status(conn, "failed-803", %{"etl_run_id" => "run-803", "state" => "failed"})

      other_scope = insert_scope("Female")
      other_draft = insert_draft!(other_scope)
      insert_request!(other_scope, other_draft, "other-run-803")
      post_status(conn, "other-run-803", %{"etl_run_id" => "other-run", "state" => "running"})

      for {request_key, draft_id, code, message} <- [
            {"queued-803", queued_draft, "invalid_status_transition",
             "Status transition is invalid"},
            {"failed-803", failed_draft, "terminal_status_conflict",
             "Transcription Request is terminal"},
            {"other-run-803", other_draft, "etl_run_conflict",
             "ETL run conflicts with this request"}
          ] do
        request = request_row(request_key)
        draft = full_draft_row(draft_id)
        response_conn = post_draft(conn, request_key, draft_params())

        assert {response_conn.status, json_response(response_conn, response_conn.status)} ==
                 {409, %{"error" => %{"code" => code, "message" => message}}}

        assert request_row(request_key) == request
        assert full_draft_row(draft_id) == draft
      end
    end

    test "a retry after a failed request runs, completes and applies", %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "first-try-803")
      post_status(conn, "first-try-803", %{"etl_run_id" => "run-803-a", "state" => "running"})
      post_status(conn, "first-try-803", %{"etl_run_id" => "run-803-a", "state" => "failed"})

      assert [["failed"]] =
               Repo.query!(
                 "SELECT state FROM blended_learning_conversation_drafts WHERE id = $1",
                 [draft_id]
               ).rows

      # af_lms resets the draft to transcribing in the same transaction that inserts the retry.
      Repo.query!(
        "UPDATE blended_learning_conversation_drafts SET state = 'transcribing' WHERE id = $1",
        [draft_id]
      )

      insert_request!(scope, draft_id, "retry-803")
      post_status(conn, "retry-803", %{"etl_run_id" => "run-803-b", "state" => "running"})

      assert submit_draft(conn, "retry-803", draft_params(%{"etl_run_id" => "run-803-b"})) == %{
               "request_state" => "completed",
               "draft_state" => "ready",
               "applied" => true
             }

      assert [["completed", "run-803-b", nil, _]] = request_row("retry-803")
      assert [["failed", "run-803-a", nil, _]] = request_row("first-try-803")

      assert Repo.query!(
               "SELECT state, draft_summary FROM blended_learning_conversation_drafts WHERE id = $1",
               [draft_id]
             ).rows == [["ready", "Asha is revising kinematics and wants weekly check-ins."]]
    end

    test "returns 404 for an unknown request key", %{conn: conn} do
      response_conn = post_draft(conn, "unknown-803", draft_params())

      assert {response_conn.status, json_response(response_conn, 404)} ==
               {404,
                %{
                  "error" => %{
                    "code" => "transcription_request_not_found",
                    "message" => "Transcription Request not found"
                  }
                }}
    end

    test "requires the existing Bearer token" do
      for authorization <- [nil, "Token malformed", "Bearer wrong-environment-secret"] do
        conn =
          if authorization,
            do: put_req_header(build_conn(), "authorization", authorization),
            else: build_conn()

        assert conn
               |> post_draft("submit-803", draft_params())
               |> response(401) == "Not Authorized"
      end
    end

    test "keeps drafted content out of debug logs", %{conn: conn} do
      scope = insert_scope("Female")
      insert_request!(scope, insert_draft!(scope), "secret-draft-803")

      post_status(conn, "secret-draft-803", %{
        "etl_run_id" => "secret-run-803",
        "state" => "running"
      })

      params =
        draft_params(%{
          "etl_run_id" => "secret-run-803",
          "summary" => "Secret summary 803",
          "action_items" => [%{"text" => "Secret action 803", "owner" => "parent"}],
          "notes" => [%{"heading" => "Secret heading 803", "points" => ["Secret point 803"]}]
        })

      {response_conn, log} =
        with_debug_log(fn ->
          post_draft(conn, "secret-draft-803", params)
          post_draft(conn, "secret-draft-803", params)
        end)

      assert json_response(response_conn, 200)["applied"] == false

      for sensitive <- [
            "Secret summary 803",
            "Secret action 803",
            "Secret heading 803",
            "Secret point 803"
          ] do
        refute log =~ sensitive
      end
    end
  end

  describe "POST /api/blended-learning/transcription-requests/:request_key/draft shape rules" do
    test "rejects each malformed draft with 422 and changes neither the request nor the draft",
         %{conn: conn} do
      scope = insert_scope("Female")
      draft_id = insert_draft!(scope)
      insert_request!(scope, draft_id, "shape-803")
      post_status(conn, "shape-803", %{"etl_run_id" => "run-803", "state" => "running"})
      age_draft!(draft_id)
      request = request_row("shape-803")
      draft = full_draft_row(draft_id)

      action_item = %{"text" => "Call the parent", "owner" => "mentor"}
      note = %{"heading" => "Physics", "points" => ["Finds graphs hard"]}

      required =
        ~w(etl_run_id transcript_s3_key summary action_items notes prompt_version model_id)

      invalid =
        [
          %{"action_items" => [%{action_item | "owner" => "teacher"}]},
          %{"action_items" => [%{action_item | "owner" => nil}]},
          %{"action_items" => [%{action_item | "text" => "  "}]},
          %{"action_items" => [Map.delete(action_item, "owner")]},
          %{"action_items" => [Map.put(action_item, "priority", "high")]},
          %{"action_items" => ["Call the parent"]},
          %{"notes" => [%{note | "heading" => " "}]},
          %{"notes" => [%{note | "points" => ["Finds graphs hard", ""]}]},
          %{"notes" => [%{note | "points" => "Finds graphs hard"}]},
          %{"notes" => [Map.delete(note, "points")]},
          %{"notes" => [Map.put(note, "source", "transcript")]},
          %{"etl_run_id" => String.duplicate("r", 256)},
          %{"transcript_s3_key" => String.duplicate("k", 256)},
          %{"prompt_version" => String.duplicate("p", 256)},
          %{"model_id" => String.duplicate("m", 256)},
          %{"summary" => " "},
          %{"summary" => "Asha is revising\u0000 kinematics."},
          %{"action_items" => [%{action_item | "text" => "Call\u0000 the parent"}]},
          %{"notes" => [%{note | "points" => ["Finds graphs\u0000 hard"]}]}
        ]
        |> Enum.map(&draft_params/1)
        |> Kernel.++(for field <- required, do: Map.delete(draft_params(), field))

      for params <- invalid do
        response_conn = post_draft(conn, "shape-803", params)

        assert {response_conn.status, json_response(response_conn, response_conn.status)} ==
                 {422,
                  %{
                    "error" => %{
                      "code" => "invalid_request",
                      "message" => "Draft fields are missing or invalid"
                    }
                  }},
               "expected 422 for #{inspect(params)}"
      end

      assert request_row("shape-803") == request
      assert full_draft_row(draft_id) == draft
    end
  end

  # A complete, valid etl-next draft submission.
  defp draft_params(overrides \\ %{}) do
    Map.merge(
      %{
        "etl_run_id" => "run-803",
        "transcript_s3_key" => "blended-learning/transcripts/803.json",
        "summary" => "Asha is revising kinematics and wants weekly check-ins.",
        "action_items" => [
          %{"text" => "Solve 20 kinematics problems", "owner" => "student"},
          %{"text" => "Share the revision timetable", "owner" => "mentor"}
        ],
        "notes" => [
          %{"heading" => "Physics", "points" => ["Finds graphs hard", "Wants more practice"]}
        ],
        "prompt_version" => "bl-draft-v1",
        "model_id" => "model-803"
      },
      overrides
    )
  end

  # etl-next posts JSON, so nulls and empty lists reach the controller as they would in production.
  defp post_draft(conn, request_key, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(
      "/api/blended-learning/transcription-requests/#{request_key}/draft",
      Jason.encode!(params)
    )
  end

  defp submit_draft(conn, request_key, params) do
    conn |> post_draft(request_key, params) |> json_response(200)
  end

  defp post_status(conn, request_key, params) do
    conn
    |> post("/api/blended-learning/transcription-requests/#{request_key}/status", params)
    |> json_response(200)
  end

  defp status_error(conn, request_key, params) do
    response_conn =
      post(conn, "/api/blended-learning/transcription-requests/#{request_key}/status", params)

    {response_conn.status, json_response(response_conn, response_conn.status)}
  end

  defp conversation_row(conversation_id) do
    Repo.query!(
      "SELECT * FROM blended_learning_conversations WHERE id = $1",
      [conversation_id]
    ).rows
  end

  defp save_draft!(scope, draft_id) do
    [[conversation_id]] =
      Repo.query!(
        """
        INSERT INTO blended_learning_conversations
          (student_id, program_id, academic_year, mentor_user_id, logged_by_email, kind,
           occurred_on, mode, spoke_with, duration_minutes, summary, source_draft_id)
        VALUES ($1, $2, '2026-2027', $3, 'mentor.private@example.org', 'conversation',
                '2026-10-20', 'call', 'student', 25, 'Saved summary', $4)
        RETURNING id
        """,
        [scope.student_id, scope.program_id, scope.mentor_user_id, draft_id]
      ).rows

    Repo.query!(
      """
      UPDATE blended_learning_conversation_drafts
      SET state = 'saved'
      WHERE id = $1
      """,
      [draft_id]
    )

    conversation_id
  end

  defp full_draft_row(draft_id) do
    Repo.query!(
      "SELECT * FROM blended_learning_conversation_drafts WHERE id = $1",
      [draft_id]
    ).rows
  end

  defp age_draft!(draft_id) do
    Repo.query!(
      """
      UPDATE blended_learning_conversation_drafts
      SET inserted_at = '2026-10-20 08:00:00', updated_at = '2026-10-20 08:00:00'
      WHERE id = $1
      """,
      [draft_id]
    )
  end

  # The state and whether updated_at is still the aged literal from age_draft!/1.
  defp draft_row(draft_id) do
    Repo.query!(
      """
      SELECT state, updated_at = '2026-10-20 08:00:00'
      FROM blended_learning_conversation_drafts
      WHERE id = $1
      """,
      [draft_id]
    ).rows
  end

  defp request_row(request_key) do
    Repo.query!(
      """
      SELECT state, etl_run_id, error_code, updated_at
      FROM blended_learning_transcription_requests
      WHERE request_key = $1
      """,
      [request_key]
    ).rows
  end

  defp collect_keys(map) when is_map(map) do
    Enum.reduce(map, MapSet.new(), fn {key, value}, keys ->
      keys |> MapSet.put(key) |> MapSet.union(collect_keys(value))
    end)
  end

  defp collect_keys(list) when is_list(list),
    do: Enum.reduce(list, MapSet.new(), &MapSet.union(collect_keys(&1), &2))

  defp collect_keys(_value), do: MapSet.new()

  defp with_debug_log(operation) do
    previous_level = Logger.level()
    Logger.configure(level: :debug)

    try do
      with_log([level: :debug], operation)
    after
      Logger.configure(level: previous_level)
    end
  end

  defp insert_scope(gender) do
    [[student_user_id], [mentor_user_id]] =
      Repo.query!(
        """
        INSERT INTO "user"
          (first_name, last_name, email, phone, whatsapp_phone, gender, inserted_at, updated_at)
        VALUES
          ('Asha', 'Private', 'asha.private@example.org', '9000000801', '9000000802', $1,
           now(), now()),
          ('Mentor', 'Private', 'mentor.private@example.org', '9000000803', NULL, 'Male',
           now(), now())
        RETURNING id
        """,
        [gender]
      ).rows

    [[student_id]] =
      Repo.query!(
        """
        INSERT INTO student
          (user_id, father_name, father_phone, mother_name, mother_phone, inserted_at, updated_at)
        VALUES ($1, 'Father Private', '9000000804', 'Mother Private', '9000000805', now(), now())
        RETURNING id
        """,
        [student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Transcription API', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Transcription API', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{mentor_user_id: mentor_user_id, program_id: program_id, student_id: student_id}
  end

  defp insert_draft!(scope) do
    [[draft_id]] =
      Repo.query!(
        """
        INSERT INTO blended_learning_conversation_drafts
          (student_id, program_id, academic_year, mentor_user_id, created_by_email, state,
           occurred_on, mode, spoke_with, duration_minutes, call_recording_s3_key,
           recording_content_type)
        VALUES ($1, $2, '2026-2027', $3, 'mentor.private@example.org', 'transcribing',
                '2026-10-20', 'call', 'student', 25, 'blended-learning/recordings/801.mp3',
                'audio/mpeg')
        RETURNING id
        """,
        [scope.student_id, scope.program_id, scope.mentor_user_id]
      ).rows

    draft_id
  end

  defp insert_request!(scope, draft_id, request_key) do
    Repo.query!(
      """
      INSERT INTO blended_learning_transcription_requests
        (request_key, draft_id, student_id, requested_by_email)
      VALUES ($1, $2, $3, 'mentor.private@example.org')
      """,
      [request_key, draft_id, scope.student_id]
    )
  end
end
