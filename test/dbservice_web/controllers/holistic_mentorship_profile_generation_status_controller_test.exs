defmodule DbserviceWeb.HolisticMentorshipProfileGenerationStatusControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import ExUnit.CaptureLog

  test "records a queued Profile generation status at the authenticated HTTP boundary", %{
    conn: conn
  } do
    student_id = insert_student!()
    configuration_id = insert_prompt_configuration!()

    response =
      conn
      |> post(
        "/api/holistic-mentorship/profile-generation-statuses",
        status_params(student_id, configuration_id)
      )
      |> json_response(200)

    assert response == %{
             "completed_outcome" => nil,
             "error_code" => nil,
             "error_message" => nil,
             "state" => "queued"
           }

    assert Repo.query!("""
           SELECT etl_run_id, student_id, form_id, af_session_id, entry_grade,
                  prompt_configuration_id, state, completed_outcome, error_code,
                  error_message, inserted_at IS NOT NULL, updated_at IS NOT NULL
           FROM holistic_mentorship_profile_generation_statuses
           """).rows == [
             [
               "etl-run-623",
               student_id,
               "6a44a83d1184e717b920c499",
               "EnableStudents_6a44a83d1184e717b920c499",
               11,
               configuration_id,
               "queued",
               nil,
               nil,
               nil,
               true,
               true
             ]
           ]
  end

  test "advances valid transitions and retries each state without duplicate rows", %{conn: conn} do
    student_id = insert_student!()
    configuration_id = insert_prompt_configuration!()

    queued = post_status(conn, status_params(student_id, configuration_id))
    assert post_status(conn, status_params(student_id, configuration_id)) == queued

    running =
      post_status(conn, status_params(student_id, configuration_id, %{"state" => "running"}))

    assert running["state"] == "running"

    assert post_status(
             conn,
             status_params(student_id, configuration_id, %{"state" => "running"})
           ) == running

    completed =
      post_status(
        conn,
        status_params(student_id, configuration_id, %{
          "completed_outcome" => "published",
          "state" => "completed"
        })
      )

    assert completed == %{
             "completed_outcome" => "published",
             "error_code" => nil,
             "error_message" => nil,
             "state" => "completed"
           }

    assert post_status(
             conn,
             status_params(student_id, configuration_id, %{
               "completed_outcome" => "published",
               "state" => "completed"
             })
           ) == completed

    assert Repo.query!("""
           SELECT count(*), min(state), min(completed_outcome)
           FROM holistic_mentorship_profile_generation_statuses
           """).rows == [[1, "completed", "published"]]
  end

  test "accepts concurrent retries of the initial queued state", %{conn: conn} do
    authorization = conn |> get_req_header("authorization") |> List.first()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      student_id = insert_student!()
      configuration_id = insert_prompt_configuration!()
      params = status_params(student_id, configuration_id)
      parent = self()

      try do
        tasks =
          for _ <- 1..2 do
            Task.async(fn ->
              Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :go ->
                    build_conn()
                    |> put_req_header("authorization", authorization)
                    |> post("/api/holistic-mentorship/profile-generation-statuses", params)
                    |> json_response(200)
                end
              end)
            end)
          end

        task_pids =
          for _ <- tasks do
            assert_receive {:ready, task_pid}
            task_pid
          end

        Enum.each(task_pids, &send(&1, :go))
        assert Enum.map(tasks, &Task.await/1) |> Enum.all?(&(&1["state"] == "queued"))

        assert Repo.query!(
                 "SELECT count(*) FROM holistic_mentorship_profile_generation_statuses WHERE etl_run_id = 'etl-run-623'"
               ).rows == [[1]]
      after
        Repo.query!(
          "TRUNCATE holistic_mentorship_regeneration_requests, holistic_mentorship_profile_generation_statuses, holistic_mentorship_student_profile_summaries, holistic_mentorship_student_profiles, holistic_mentorship_prompt_configurations, holistic_mentorship_prompt_versions RESTART IDENTITY"
        )

        Repo.query!(
          "WITH deleted AS (DELETE FROM student WHERE id = $1 RETURNING user_id) DELETE FROM \"user\" WHERE id IN (SELECT user_id FROM deleted)",
          [student_id]
        )
      end
    end)
  end

  test "rejects invalid source, result, and unbounded error metadata with a stable safe error", %{
    conn: conn
  } do
    student_id = insert_student!()
    configuration_id = insert_prompt_configuration!()
    params = status_params(student_id, configuration_id)

    invalid_requests = [
      Map.merge(params, %{"state" => "completed"}),
      Map.merge(params, %{"completed_outcome" => "invented", "state" => "completed"}),
      Map.merge(params, %{"error_message" => String.duplicate("x", 501), "state" => "failed"}),
      Map.put(params, "etl_run_id", String.duplicate("r", 256)),
      Map.put(params, "form_id", "unapproved-form")
    ]

    for invalid_params <- invalid_requests do
      assert conn
             |> post("/api/holistic-mentorship/profile-generation-statuses", invalid_params)
             |> json_response(422) == %{
               "error" => %{
                 "code" => "invalid_request",
                 "message" => "Profile generation status fields are missing or invalid"
               }
             }
    end

    assert Repo.query!("SELECT count(*) FROM holistic_mentorship_profile_generation_statuses").rows ==
             [[0]]
  end

  test "rejects regressions and changes to terminal status with stable safe codes", %{conn: conn} do
    student_id = insert_student!()
    configuration_id = insert_prompt_configuration!()
    params = status_params(student_id, configuration_id)

    assert_error(
      post(
        conn,
        "/api/holistic-mentorship/profile-generation-statuses",
        Map.put(params, "state", "running")
      ),
      "invalid_status_transition",
      "Profile generation status transition is invalid"
    )

    post_status(conn, params)
    post_status(conn, Map.put(params, "state", "running"))

    assert_error(
      post(conn, "/api/holistic-mentorship/profile-generation-statuses", params),
      "invalid_status_transition",
      "Profile generation status transition is invalid"
    )

    post_status(
      conn,
      Map.merge(params, %{"state" => "failed", "error_code" => "upstream_timeout"})
    )

    assert_error(
      post(
        conn,
        "/api/holistic-mentorship/profile-generation-statuses",
        Map.merge(params, %{"state" => "failed", "error_code" => "different_error"})
      ),
      "terminal_status_conflict",
      "Profile generation status is terminal"
    )
  end

  test "rejects unknown canonical identities without exposing them in responses or logs", %{
    conn: conn
  } do
    configuration_id = insert_prompt_configuration!()
    unknown_student_id = 2_147_483_646

    {conn, log} =
      with_debug_log(fn ->
        post(
          conn,
          "/api/holistic-mentorship/profile-generation-statuses",
          status_params(unknown_student_id, configuration_id, %{
            "answers" => "sensitive answers",
            "prompt" => "sensitive prompt",
            "source_user_id" => "sensitive-source-user",
            "summaries" => ["sensitive summary"]
          })
        )
      end)

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Profile generation status fields are missing or invalid"
             }
           }

    for sensitive <- [
          Integer.to_string(unknown_student_id),
          "sensitive answers",
          "sensitive prompt",
          "sensitive-source-user",
          "sensitive summary"
        ] do
      refute conn.resp_body =~ sensitive
      refute log =~ sensitive
    end
  end

  test "failed and invalid updates preserve the successful Profile and redact sensitive input", %{
    conn: conn
  } do
    student_id = insert_student!()
    configuration_id = insert_prompt_configuration!()
    profile_id = insert_successful_profile!(student_id, configuration_id)
    params = status_params(student_id, configuration_id)
    error_message = String.duplicate("s", 500)

    post_status(conn, params)
    post_status(conn, Map.put(params, "state", "running"))

    {failed_conn, log} =
      with_debug_log(fn ->
        post(
          conn,
          "/api/holistic-mentorship/profile-generation-statuses",
          Map.merge(params, %{
            "answers" => "private answers 623",
            "error_code" => "upstream_timeout",
            "error_message" => error_message,
            "prompt" => "private prompt 623",
            "source_user_id" => "private-source-user-623",
            "state" => "failed",
            "summaries" => ["private summary 623"]
          })
        )
      end)

    assert json_response(failed_conn, 200) == %{
             "completed_outcome" => nil,
             "error_code" => "upstream_timeout",
             "error_message" => error_message,
             "state" => "failed"
           }

    for sensitive <- [
          "private answers 623",
          "private prompt 623",
          "private-source-user-623",
          "private summary 623"
        ] do
      refute failed_conn.resp_body =~ sensitive
      refute log =~ sensitive
    end

    assert Repo.query!(
             """
             SELECT profile.id, profile.answer_fingerprint, profile.revision, count(summary.id)
             FROM holistic_mentorship_student_profiles AS profile
             JOIN holistic_mentorship_student_profile_summaries AS summary
               ON summary.student_profile_id = profile.id
             WHERE profile.id = $1
             GROUP BY profile.id
             """,
             [profile_id]
           ).rows == [[profile_id, "answers-success", 2, 5]]
  end

  test "requires the existing Bearer token", %{conn: _conn} do
    assert build_conn()
           |> post("/api/holistic-mentorship/profile-generation-statuses", %{})
           |> response(401) == "Not Authorized"
  end

  defp assert_error(conn, code, message) do
    assert json_response(conn, 409) == %{"error" => %{"code" => code, "message" => message}}
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

  defp post_status(conn, params) do
    conn
    |> post("/api/holistic-mentorship/profile-generation-statuses", params)
    |> json_response(200)
  end

  defp status_params(student_id, configuration_id, overrides \\ %{}) do
    Map.merge(
      %{
        "af_session_id" => "EnableStudents_6a44a83d1184e717b920c499",
        "entry_grade" => 11,
        "etl_run_id" => "etl-run-623",
        "form_id" => "6a44a83d1184e717b920c499",
        "prompt_configuration_id" => configuration_id,
        "state" => "queued",
        "student_id" => student_id
      },
      overrides
    )
  end

  defp insert_student! do
    [[user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [user_id]
      ).rows

    student_id
  end

  defp insert_prompt_configuration! do
    [[prompt_version_id]] =
      Repo.query!("""
      INSERT INTO holistic_mentorship_prompt_versions (version, template_text, template_hash)
      VALUES ('generation-status-v1', 'abc',
              'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
      RETURNING id
      """).rows

    [[configuration_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_prompt_configurations (prompt_version_id, model_id)
        VALUES ($1, 'openai/gpt-5-mini')
        RETURNING id
        """,
        [prompt_version_id]
      ).rows

    configuration_id
  end

  defp insert_successful_profile!(student_id, configuration_id) do
    [[journey_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_profile_journeys
          (student_id, form_id, af_session_id, entry_grade)
        VALUES ($1, '6a44a83d1184e717b920c499',
                'EnableStudents_6a44a83d1184e717b920c499', 11)
        RETURNING id
        """,
        [student_id]
      ).rows

    [[profile_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profiles
          (profile_journey_id, prompt_configuration_id, schema_fingerprint,
           answer_fingerprint, warehouse_loaded_at, generated_at, revision,
           last_successful_etl_run_id)
        VALUES ($1, $2, 'schema-success', 'answers-success', '2026-07-16 10:00:00',
                '2026-07-16 10:05:00', 2, 'etl-success')
        RETURNING id
        """,
        [journey_id, configuration_id]
      ).rows

    for position <- 1..5 do
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profile_summaries
          (student_profile_id, position, question_set_title, summary)
        VALUES ($1, $2, $3, $4)
        """,
        [profile_id, position, "Question Set #{position}", "Summary #{position}"]
      )
    end

    profile_id
  end
end
