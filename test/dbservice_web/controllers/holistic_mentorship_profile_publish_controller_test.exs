defmodule DbserviceWeb.HolisticMentorshipProfilePublishControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import Dbservice.GradesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.UsersFixtures
  import ExUnit.CaptureLog

  @source %{
    "af_session_id" => "EnableStudents_6a44a83d1184e717b920c499",
    "entry_grade" => 11,
    "form_id" => "6a44a83d1184e717b920c499"
  }

  test "publishes one complete Student Profile and completes its generation status", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "publish-run-1")

    response =
      conn
      |> post(
        "/api/holistic-mentorship/profiles/publish",
        publish_params(user.id, student.id, configuration_id, "publish-run-1")
      )
      |> json_response(200)

    assert response == %{"result" => "published", "revision" => 1}

    assert Repo.query!("""
           SELECT profile.revision, profile.answer_fingerprint, status.state,
                  status.completed_outcome, summary.position, summary.question_set_title,
                  summary.summary
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           JOIN holistic_mentorship_profile_generation_statuses AS status
             ON status.etl_run_id = profile.last_successful_etl_run_id
           ORDER BY summary.position
           """).rows ==
             (for position <- 1..5 do
                [
                  1,
                  "answers-v1",
                  "completed",
                  "published",
                  position,
                  "Question Set #{position}",
                  "Fixed summary #{position}"
                ]
              end)
  end

  test "replaces changed answers for the same configuration", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "replace-run-1")

    assert publish(conn, publish_params(user.id, student.id, configuration_id, "replace-run-1")) ==
             %{"result" => "published", "revision" => 1}

    insert_running_status!(student.id, configuration_id, "replace-run-2")

    params =
      publish_params(user.id, student.id, configuration_id, "replace-run-2", %{
        "answer_fingerprint" => "answers-v2",
        "expected_profile_revision" => 1,
        "summaries" => summaries("Replacement")
      })

    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}

    assert Repo.query!("""
           SELECT profile.revision, profile.answer_fingerprint, profile.last_successful_etl_run_id,
                  count(summary.id), min(summary.summary), max(summary.summary)
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           GROUP BY profile.id
           """).rows == [[2, "answers-v2", "replace-run-2", 5, "Replacement 1", "Replacement 5"]]
  end

  test "returns unchanged without replacing a matching answer fingerprint", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "unchanged-run-1")
    publish(conn, publish_params(user.id, student.id, configuration_id, "unchanged-run-1"))
    insert_running_status!(student.id, configuration_id, "unchanged-run-2")

    params =
      publish_params(user.id, student.id, configuration_id, "unchanged-run-2", %{
        "expected_profile_revision" => 1,
        "summaries" => summaries("Should not persist")
      })

    assert publish(conn, params) == %{"result" => "unchanged", "revision" => 1}

    assert Repo.query!("""
           SELECT profile.revision, profile.last_successful_etl_run_id,
                  min(summary.summary), status.completed_outcome
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           JOIN holistic_mentorship_profile_generation_statuses AS status
             ON status.etl_run_id = 'unchanged-run-2'
           GROUP BY profile.id, status.completed_outcome
           """).rows == [[1, "unchanged-run-1", "Fixed summary 1", "unchanged"]]
  end

  test "an authorized force request replaces unchanged answers and completes atomically", %{
    conn: conn
  } do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "force-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "force-base"))

    other_configuration_id = insert_prompt_configuration!("openai/gpt-5")
    insert_running_status!(student.id, other_configuration_id, "force-other-configuration")

    publish(
      conn,
      publish_params(user.id, student.id, other_configuration_id, "force-other-configuration")
    )

    insert_running_status!(student.id, configuration_id, "force-run")
    insert_regeneration_request!("force-request", user.id, student.id, configuration_id)

    params =
      publish_params(user.id, student.id, configuration_id, "force-run", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "force-request",
        "summaries" => summaries("Forced")
      })

    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}

    assert Repo.query!(
             """
             SELECT profile.revision, profile.answer_fingerprint, min(summary.summary),
                    status.state, status.completed_outcome, request.state, request.etl_run_id,
                    request.requested_by_user_id
             FROM holistic_mentorship_student_profiles AS profile
             JOIN holistic_mentorship_student_profile_summaries AS summary
               ON summary.student_profile_id = profile.id
             JOIN holistic_mentorship_profile_generation_statuses AS status
               ON status.etl_run_id = 'force-run'
             JOIN holistic_mentorship_regeneration_requests AS request
               ON request.request_key = 'force-request'
             WHERE profile.prompt_configuration_id = $1
             GROUP BY profile.id, status.state, status.completed_outcome, request.state,
                      request.etl_run_id, request.requested_by_user_id
             """,
             [configuration_id]
           ).rows ==
             [
               [
                 2,
                 "answers-v1",
                 "Forced 1",
                 "completed",
                 "replaced",
                 "completed",
                 "force-run",
                 user.id
               ]
             ]

    assert Repo.query!(
             """
             SELECT revision, last_successful_etl_run_id
             FROM holistic_mentorship_student_profiles
             WHERE prompt_configuration_id = $1
             """,
             [other_configuration_id]
           ).rows == [[1, "force-other-configuration"]]
  end

  test "a running request authorizes force publication for its ETL run", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "running-force-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "running-force-base"))

    insert_running_status!(student.id, configuration_id, "running-force-run")
    insert_regeneration_request!("running-force-request", user.id, student.id, configuration_id)

    Repo.query!("""
    UPDATE holistic_mentorship_regeneration_requests
    SET state = 'running', etl_run_id = 'running-force-run'
    WHERE request_key = 'running-force-request'
    """)

    params =
      publish_params(user.id, student.id, configuration_id, "running-force-run", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "running-force-request"
      })

    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}

    assert Repo.query!("""
           SELECT state, etl_run_id FROM holistic_mentorship_regeneration_requests
           WHERE request_key = 'running-force-request'
           """).rows == [["completed", "running-force-run"]]
  end

  test "a queued force request follows the request state machine", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "queued-force-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "queued-force-base"))

    insert_running_status!(student.id, configuration_id, "queued-force-run")
    insert_regeneration_request!("queued-force-request", user.id, student.id, configuration_id)

    Repo.query!("""
    CREATE FUNCTION reject_queued_to_completed() RETURNS trigger AS $$
    BEGIN
      IF OLD.request_key = 'queued-force-request'
         AND OLD.state = 'queued' AND NEW.state = 'completed' THEN
        RAISE EXCEPTION 'invalid regeneration transition';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_queued_to_completed
    BEFORE UPDATE ON holistic_mentorship_regeneration_requests
    FOR EACH ROW EXECUTE FUNCTION reject_queued_to_completed()
    """)

    params =
      publish_params(user.id, student.id, configuration_id, "queued-force-run", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "queued-force-request"
      })

    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}

    assert Repo.query!("""
           SELECT state, etl_run_id FROM holistic_mentorship_regeneration_requests
           WHERE request_key = 'queued-force-request'
           """).rows == [["completed", "queued-force-run"]]
  end

  test "repeating a completed force publication returns its prior result", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "force-repeat-base")

    publish(
      conn,
      publish_params(user.id, student.id, configuration_id, "force-repeat-base")
    )

    insert_running_status!(student.id, configuration_id, "force-repeat")
    insert_regeneration_request!("force-repeat-request", user.id, student.id, configuration_id)

    params =
      publish_params(user.id, student.id, configuration_id, "force-repeat", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "force-repeat-request",
        "summaries" => summaries("Repeated force")
      })

    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}
    assert publish(conn, params) == %{"result" => "replaced", "revision" => 2}

    assert Repo.query!("""
           SELECT profile.revision, count(summary.id), request.state, request.etl_run_id
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           JOIN holistic_mentorship_regeneration_requests AS request
             ON request.request_key = 'force-repeat-request'
           GROUP BY profile.id, request.state, request.etl_run_id
           """).rows == [[2, 5, "completed", "force-repeat"]]
  end

  test "a terminal force request cannot authorize new publication work", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "terminal-force-base")

    publish(
      conn,
      publish_params(user.id, student.id, configuration_id, "terminal-force-base")
    )

    insert_running_status!(student.id, configuration_id, "terminal-force-run")
    insert_regeneration_request!("terminal-force-request", user.id, student.id, configuration_id)

    Repo.query!("""
    UPDATE holistic_mentorship_regeneration_requests
    SET state = 'completed', etl_run_id = 'terminal-force-run'
    WHERE request_key = 'terminal-force-request'
    """)

    params =
      publish_params(user.id, student.id, configuration_id, "terminal-force-run", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "terminal-force-request"
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", params)
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("SELECT revision FROM holistic_mentorship_student_profiles").rows == [[1]]

    assert Repo.query!("""
           SELECT state FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id = 'terminal-force-run'
           """).rows == [["running"]]
  end

  test "force publication rejects missing, mismatched, non-force, and failed requests", %{
    conn: conn
  } do
    {user, student} = eligible_student()
    {_other_user, other_student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    other_configuration_id = insert_prompt_configuration!("openai/gpt-5")
    insert_running_status!(student.id, configuration_id, "force-invalid-base")

    publish(
      conn,
      publish_params(user.id, student.id, configuration_id, "force-invalid-base")
    )

    insert_regeneration_request!(
      "force-wrong-student",
      user.id,
      other_student.id,
      configuration_id
    )

    insert_regeneration_request!(
      "force-wrong-configuration",
      user.id,
      student.id,
      other_configuration_id
    )

    insert_regeneration_request!("force-disabled", user.id, student.id, configuration_id, false)
    insert_regeneration_request!("force-failed", user.id, student.id, configuration_id)
    insert_regeneration_request!("force-wrong-run", user.id, student.id, configuration_id)

    Repo.query!("""
    UPDATE holistic_mentorship_regeneration_requests
    SET state = 'failed', etl_run_id = 'failed-run'
    WHERE request_key = 'force-failed'
    """)

    Repo.query!("""
    UPDATE holistic_mentorship_regeneration_requests
    SET state = 'running', etl_run_id = 'different-run'
    WHERE request_key = 'force-wrong-run'
    """)

    cases = [
      {"force-missing", nil},
      {"force-unknown", "unknown-request"},
      {"force-student-mismatch", "force-wrong-student"},
      {"force-configuration-mismatch", "force-wrong-configuration"},
      {"force-disabled-run", "force-disabled"},
      {"force-failed-run", "force-failed"},
      {"force-etl-run-mismatch", "force-wrong-run"}
    ]

    for {run_id, request_key} <- cases do
      insert_running_status!(student.id, configuration_id, run_id)

      params =
        publish_params(user.id, student.id, configuration_id, run_id, %{
          "expected_profile_revision" => 1,
          "force" => true
        })
        |> then(fn params ->
          if request_key,
            do: Map.put(params, "regeneration_request_key", request_key),
            else: params
        end)

      assert conn
             |> recycle()
             |> post("/api/holistic-mentorship/profiles/publish", params)
             |> json_response(422) == %{
               "error" => %{
                 "code" => "invalid_request",
                 "message" => "Profile publication request is invalid"
               }
             }
    end

    assert Repo.query!("SELECT revision FROM holistic_mentorship_student_profiles").rows == [[1]]

    assert Repo.query!("""
           SELECT count(*) FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id LIKE 'force-%' AND state = 'running'
           """).rows == [[7]]
  end

  test "validation, stale, and child failures preserve Profile, status, and force request", %{
    conn: conn
  } do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "force-rollback-base")

    publish(
      conn,
      publish_params(user.id, student.id, configuration_id, "force-rollback-base")
    )

    for {run_id, request_key} <- [
          {"force-rollback-validation", "force-validation-request"},
          {"force-rollback-stale", "force-stale-request"},
          {"force-rollback-child", "force-child-request"}
        ] do
      insert_running_status!(student.id, configuration_id, run_id)
      insert_regeneration_request!(request_key, user.id, student.id, configuration_id)
    end

    validation =
      publish_params(user.id, student.id, configuration_id, "force-rollback-validation", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "force-validation-request"
      })

    Repo.query!("UPDATE student SET status = 'dropout' WHERE id = $1", [student.id])

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", validation)
           |> json_response(422) == %{
             "error" => %{
               "code" => "dropout",
               "message" => "Profile publication is not eligible"
             }
           }

    Repo.query!("UPDATE student SET status = 'active' WHERE id = $1", [student.id])

    stale =
      publish_params(user.id, student.id, configuration_id, "force-rollback-stale", %{
        "expected_profile_revision" => 2,
        "force" => true,
        "regeneration_request_key" => "force-stale-request"
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", stale)
           |> json_response(409) == %{
             "error" => %{
               "code" => "stale_profile_revision",
               "message" => "Profile revision is stale"
             }
           }

    invalid_child =
      publish_params(user.id, student.id, configuration_id, "force-rollback-child", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "force-child-request",
        "summaries" => [
          %{
            "position" => 1,
            "question_set_title" => String.duplicate("x", 256),
            "summary" => "invalid child"
          }
          | Enum.drop(summaries("Replacement"), 1)
        ]
      })

    assert conn
           |> recycle()
           |> post("/api/holistic-mentorship/profiles/publish", invalid_child)
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("""
           SELECT profile.revision, min(summary.summary)
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           GROUP BY profile.id
           """).rows == [[1, "Fixed summary 1"]]

    assert Repo.query!("""
           SELECT state FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id IN (
             'force-rollback-validation', 'force-rollback-stale', 'force-rollback-child'
           )
           ORDER BY etl_run_id
           """).rows == [["running"], ["running"], ["running"]]

    assert Repo.query!("""
           SELECT state FROM holistic_mentorship_regeneration_requests
           WHERE request_key IN (
             'force-validation-request', 'force-stale-request', 'force-child-request'
           )
           ORDER BY request_key
           """).rows == [["queued"], ["queued"], ["queued"]]
  end

  test "a request transition failure preserves the prior successful Profile", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "transition-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "transition-base"))

    insert_running_status!(student.id, configuration_id, "transition-failure")

    insert_regeneration_request!(
      "failing-request-transition",
      user.id,
      student.id,
      configuration_id
    )

    Repo.query!("""
    CREATE FUNCTION reject_test_regeneration_completion() RETURNS trigger AS $$
    BEGIN
      IF OLD.request_key = 'failing-request-transition' AND NEW.state = 'completed' THEN
        RETURN NULL;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_test_regeneration_completion
    BEFORE UPDATE ON holistic_mentorship_regeneration_requests
    FOR EACH ROW EXECUTE FUNCTION reject_test_regeneration_completion()
    """)

    params =
      publish_params(user.id, student.id, configuration_id, "transition-failure", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "failing-request-transition",
        "summaries" => summaries("Must roll back")
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", params)
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("""
           SELECT profile.revision, min(summary.summary), status.state, request.state
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           JOIN holistic_mentorship_profile_generation_statuses AS status
             ON status.etl_run_id = 'transition-failure'
           JOIN holistic_mentorship_regeneration_requests AS request
             ON request.request_key = 'failing-request-transition'
           GROUP BY profile.id, status.state, request.state
           """).rows == [[1, "Fixed summary 1", "running", "queued"]]
  end

  test "a generation status completion failure preserves the prior successful Profile", %{
    conn: conn
  } do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "status-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "status-base"))

    insert_running_status!(student.id, configuration_id, "status-failure")
    insert_regeneration_request!("status-failure-request", user.id, student.id, configuration_id)

    Repo.query!("""
    CREATE FUNCTION reject_test_status_completion() RETURNS trigger AS $$
    BEGIN
      IF OLD.etl_run_id = 'status-failure' AND NEW.state = 'completed' THEN
        RETURN NULL;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_test_status_completion
    BEFORE UPDATE ON holistic_mentorship_profile_generation_statuses
    FOR EACH ROW EXECUTE FUNCTION reject_test_status_completion()
    """)

    params =
      publish_params(user.id, student.id, configuration_id, "status-failure", %{
        "expected_profile_revision" => 1,
        "force" => true,
        "regeneration_request_key" => "status-failure-request",
        "summaries" => summaries("Must roll back")
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", params)
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("""
           SELECT profile.revision, min(summary.summary), status.state, request.state
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           JOIN holistic_mentorship_profile_generation_statuses AS status
             ON status.etl_run_id = 'status-failure'
           JOIN holistic_mentorship_regeneration_requests AS request
             ON request.request_key = 'status-failure-request'
           GROUP BY profile.id, status.state, request.state
           """).rows == [[1, "Fixed summary 1", "running", "queued"]]
  end

  test "repeating a completed run cannot replay older output", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "repeat-old")
    old_params = publish_params(user.id, student.id, configuration_id, "repeat-old")
    assert publish(conn, old_params) == %{"result" => "published", "revision" => 1}

    insert_running_status!(student.id, configuration_id, "repeat-new")

    new_params =
      publish_params(user.id, student.id, configuration_id, "repeat-new", %{
        "answer_fingerprint" => "answers-new",
        "expected_profile_revision" => 1,
        "summaries" => summaries("Newest")
      })

    assert publish(conn, new_params) == %{"result" => "replaced", "revision" => 2}
    assert publish(conn, old_params) == %{"result" => "published", "revision" => 1}

    assert Repo.query!("""
           SELECT profile.answer_fingerprint, profile.revision, min(summary.summary)
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           GROUP BY profile.id
           """).rows == [["answers-new", 2, "Newest 1"]]
  end

  test "stale revisions and child-write failures roll back the whole publication", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "rollback-base")
    publish(conn, publish_params(user.id, student.id, configuration_id, "rollback-base"))

    insert_running_status!(student.id, configuration_id, "rollback-stale")

    stale =
      publish_params(user.id, student.id, configuration_id, "rollback-stale", %{
        "answer_fingerprint" => "stale-answers",
        "expected_profile_revision" => 2
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", stale)
           |> json_response(409) == %{
             "error" => %{
               "code" => "stale_profile_revision",
               "message" => "Profile revision is stale"
             }
           }

    insert_running_status!(student.id, configuration_id, "rollback-child")

    invalid_child =
      publish_params(user.id, student.id, configuration_id, "rollback-child", %{
        "answer_fingerprint" => "child-answers",
        "expected_profile_revision" => 1,
        "summaries" => [
          %{
            "position" => 1,
            "question_set_title" => String.duplicate("x", 256),
            "summary" => "invalid child"
          }
          | Enum.drop(summaries("Replacement"), 1)
        ]
      })

    assert conn
           |> post("/api/holistic-mentorship/profiles/publish", invalid_child)
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("""
           SELECT profile.revision, profile.answer_fingerprint, min(summary.summary)
           FROM holistic_mentorship_student_profiles AS profile
           JOIN holistic_mentorship_student_profile_summaries AS summary
             ON summary.student_profile_id = profile.id
           GROUP BY profile.id
           """).rows == [[1, "answers-v1", "Fixed summary 1"]]

    assert Repo.query!("""
           SELECT etl_run_id, state FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id IN ('rollback-stale', 'rollback-child') ORDER BY etl_run_id
           """).rows == [["rollback-child", "running"], ["rollback-stale", "running"]]
  end

  test "rejects a malformed source User ID safely", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "malformed-source")

    assert conn
           |> post(
             "/api/holistic-mentorship/profiles/publish",
             publish_params(user.id, student.id, configuration_id, "malformed-source", %{
               "source_user_id" => user.id
             })
           )
           |> json_response(422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile publication request is invalid"
             }
           }

    assert Repo.query!("""
           SELECT state FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id = 'malformed-source'
           """).rows == [["running"]]
  end

  test "concurrent workers allow one replacement and reject the stale writer", %{conn: conn} do
    authorization = conn |> get_req_header("authorization") |> List.first()

    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "concurrent-base")

    publish(
      build_conn(authorization),
      publish_params(user.id, student.id, configuration_id, "concurrent-base")
    )

    for run_id <- ["concurrent-a", "concurrent-b"] do
      insert_running_status!(student.id, configuration_id, run_id)
    end

    parent = self()

    tasks =
      for {run_id, fingerprint} <- [
            {"concurrent-a", "answers-a"},
            {"concurrent-b", "answers-b"}
          ] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              response =
                build_conn(authorization)
                |> post(
                  "/api/holistic-mentorship/profiles/publish",
                  publish_params(user.id, student.id, configuration_id, run_id, %{
                    "answer_fingerprint" => fingerprint,
                    "expected_profile_revision" => 1
                  })
                )

              {response.status, Jason.decode!(response.resp_body)}
          end
        end)
      end

    task_pids =
      for _ <- tasks do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await/1)

    assert Enum.sort(Enum.map(results, &elem(&1, 0))) == [200, 409]
    assert Enum.any?(results, fn {_, body} -> body["result"] == "replaced" end)

    assert Repo.query!("SELECT revision FROM holistic_mentorship_student_profiles").rows == [[2]]
  end

  test "revalidates eligibility at publication time", %{conn: conn} do
    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "ineligible-run")
    Repo.query!("UPDATE student SET status = 'dropout' WHERE id = $1", [student.id])

    response =
      conn
      |> post(
        "/api/holistic-mentorship/profiles/publish",
        publish_params(user.id, student.id, configuration_id, "ineligible-run")
      )
      |> json_response(422)

    assert response == %{
             "error" => %{
               "code" => "dropout",
               "message" => "Profile publication is not eligible"
             }
           }

    assert Repo.query!("SELECT count(*) FROM holistic_mentorship_profile_journeys").rows == [[0]]
    refute inspect(response) =~ Integer.to_string(student.id)
    refute inspect(response) =~ Integer.to_string(user.id)
  end

  test "retains a Profile published for another Prompt Configuration", %{conn: conn} do
    {user, student} = eligible_student()
    first_configuration = insert_prompt_configuration!()
    second_configuration = insert_prompt_configuration!("openai/gpt-5")
    insert_running_status!(student.id, first_configuration, "configuration-first")

    publish(
      conn,
      publish_params(user.id, student.id, first_configuration, "configuration-first")
    )

    insert_running_status!(student.id, second_configuration, "configuration-second")

    assert publish(
             conn,
             publish_params(user.id, student.id, second_configuration, "configuration-second")
           ) == %{"result" => "published", "revision" => 1}

    assert Repo.query!("""
           SELECT prompt_configuration_id, revision
           FROM holistic_mentorship_student_profiles
           ORDER BY prompt_configuration_id
           """).rows == [[first_configuration, 1], [second_configuration, 1]]
  end

  test "requires authentication and redacts publication content from errors and logs", %{
    conn: conn
  } do
    assert build_conn()
           |> post("/api/holistic-mentorship/profiles/publish", %{})
           |> response(401) == "Not Authorized"

    {user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_running_status!(student.id, configuration_id, "redacted-run")
    Repo.query!("UPDATE student SET status = 'dropout' WHERE id = $1", [student.id])

    params =
      publish_params(user.id, student.id, configuration_id, "redacted-run", %{
        "answer_fingerprint" => "private-answer-fingerprint",
        "summaries" => summaries("private-summary")
      })

    {response, log} =
      with_debug_log(fn ->
        conn
        |> post("/api/holistic-mentorship/profiles/publish", params)
        |> json_response(422)
      end)

    for sensitive <- [
          Integer.to_string(user.id),
          Integer.to_string(student.id),
          "private-answer-fingerprint",
          "private-summary"
        ] do
      refute inspect(response) =~ sensitive
      refute log =~ sensitive
    end
  end

  defp eligible_student do
    grade = grade_fixture(%{number: 11})
    {user, student} = student_fixture(%{grade_id: grade.id, status: "active"})
    school = school_fixture(%{program_ids: [1], code: "publish-school-#{user.id}"})

    enroll(user.id, "school", school.id)
    enroll(user.id, "grade", grade.id)
    {user, student}
  end

  defp enroll(user_id, group_type, group_id) do
    {:ok, _} =
      Dbservice.EnrollmentRecords.create_enrollment_record(%{
        user_id: user_id,
        group_id: group_id,
        group_type: group_type,
        academic_year: "2026-27",
        start_date: ~D[2026-06-01],
        is_current: true
      })
  end

  defp insert_prompt_configuration!(model_id \\ "openai/gpt-5-mini") do
    [[version_id]] =
      Repo.query!("""
      INSERT INTO holistic_mentorship_prompt_versions (version, template_text, template_hash)
      VALUES ('publish-v1', 'abc',
              'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
      ON CONFLICT (version) DO UPDATE SET version = EXCLUDED.version
      RETURNING id
      """).rows

    [[configuration_id]] =
      Repo.query!(
        "INSERT INTO holistic_mentorship_prompt_configurations (prompt_version_id, model_id) VALUES ($1, $2) RETURNING id",
        [version_id, model_id]
      ).rows

    configuration_id
  end

  defp insert_running_status!(student_id, configuration_id, run_id) do
    Repo.query!(
      """
      INSERT INTO holistic_mentorship_profile_generation_statuses
        (etl_run_id, student_id, form_id, af_session_id, entry_grade,
         prompt_configuration_id, state)
      VALUES ($1, $2, $3, $4, $5, $6, 'running')
      """,
      [
        run_id,
        student_id,
        @source["form_id"],
        @source["af_session_id"],
        @source["entry_grade"],
        configuration_id
      ]
    )
  end

  defp insert_regeneration_request!(
         request_key,
         actor_id,
         student_id,
         configuration_id,
         force \\ true
       ) do
    Repo.query!(
      """
      INSERT INTO holistic_mentorship_regeneration_requests
        (request_key, requested_by_user_id, student_id, prompt_configuration_id, force, state)
      VALUES ($1, $2, $3, $4, $5, 'queued')
      """,
      [request_key, actor_id, student_id, configuration_id, force]
    )
  end

  defp publish(conn, params) do
    conn
    |> post("/api/holistic-mentorship/profiles/publish", params)
    |> json_response(200)
  end

  defp publish_params(user_id, student_id, configuration_id, run_id, overrides \\ %{}) do
    Map.merge(@source, %{
      "answer_fingerprint" => "answers-v1",
      "etl_run_id" => run_id,
      "expected_profile_revision" => nil,
      "force" => false,
      "generated_at" => "2026-07-16T10:05:00Z",
      "prompt_configuration_id" => configuration_id,
      "schema_fingerprint" => "schema-v1",
      "source_user_id" => Integer.to_string(user_id),
      "student_id" => student_id,
      "summaries" => summaries("Fixed summary"),
      "warehouse_loaded_at" => "2026-07-16T10:00:00Z"
    })
    |> Map.merge(overrides)
  end

  defp summaries(prefix) do
    for position <- 1..5 do
      %{
        "position" => position,
        "question_set_title" => "Question Set #{position}",
        "summary" => "#{prefix} #{position}"
      }
    end
  end

  defp build_conn(authorization) do
    Phoenix.ConnTest.build_conn()
    |> put_req_header("authorization", authorization)
  end

  defp with_debug_log(operation) do
    previous_level = Logger.level()
    Logger.configure(level: :debug)

    try do
      with_log([level: :debug], operation)
    after
      Logger.configure(level: previous_level)
    end
  end
end
