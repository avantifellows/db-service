defmodule DbserviceWeb.HolisticMentorshipRegenerationRequestControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import Dbservice.GradesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.UsersFixtures
  import ExUnit.CaptureLog

  test "returns an eligible queued Regeneration Request created by af_lms", %{conn: conn} do
    {student_user, student} = eligible_student()
    admin = user_fixture()
    configuration_id = insert_prompt_configuration!()

    Repo.query!(
      """
      INSERT INTO holistic_mentorship_regeneration_requests
        (request_key, requested_by_user_id, student_id, prompt_configuration_id, force, state)
      VALUES ('request-624', $1, $2, $3, true, 'queued')
      """,
      [admin.id, student.id, configuration_id]
    )

    assert conn
           |> get("/api/holistic-mentorship/regeneration-requests/request-624")
           |> json_response(200) == %{
             "etl_run_id" => nil,
             "force" => true,
             "model_id" => "openai/gpt-5-mini",
             "prompt_configuration_id" => configuration_id,
             "prompt_version" => "regeneration-v1",
             "request_key" => "request-624",
             "state" => "queued",
             "student_id" => student.id,
             "template_hash" => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
           }

    refute student_user.id == admin.id
  end

  test "rejects a queued request for a privacy-deleted Student", %{conn: conn} do
    {_student_user, student} = eligible_student()
    admin = user_fixture()
    configuration_id = insert_prompt_configuration!()
    insert_request!(admin.id, student.id, configuration_id, "privacy-deleted-request")

    Repo.query!(
      """
      INSERT INTO holistic_mentorship_privacy_deletions
        (student_id, actor_user_id, reason, profile_summaries_erased,
         post_session_answers_erased, historical_answers_erased, occurred_at)
      VALUES ($1, $2, 'approved-request', 0, 0, 0, now())
      """,
      [student.id, admin.id]
    )

    assert conn
           |> get("/api/holistic-mentorship/regeneration-requests/privacy-deleted-request")
           |> json_response(422) == %{
             "error" => %{
               "code" => "privacy_erased",
               "message" => "Student is not eligible"
             }
           }
  end

  test "keeps the human actor and request identity immutable" do
    {_student_user, student} = eligible_student()
    admin = user_fixture()
    replacement_admin = user_fixture()
    configuration_id = insert_prompt_configuration!()

    [[request_id, true, true]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_regeneration_requests
          (request_key, requested_by_user_id, student_id, prompt_configuration_id, force, state)
        VALUES ('immutable-request', $1, $2, $3, true, 'queued')
        RETURNING id, inserted_at IS NOT NULL, updated_at IS NOT NULL
        """,
        [admin.id, student.id, configuration_id]
      ).rows

    assert_unique_violation(fn ->
      Repo.query(
        """
        INSERT INTO holistic_mentorship_regeneration_requests
          (request_key, requested_by_user_id, student_id, prompt_configuration_id, force, state)
        VALUES ('immutable-request', $1, $2, $3, true, 'queued')
        """,
        [admin.id, student.id, configuration_id]
      )
    end)

    assert_check_violation(fn ->
      Repo.query(
        """
        UPDATE holistic_mentorship_regeneration_requests
        SET request_key = 'changed', requested_by_user_id = $2, force = false
        WHERE id = $1
        """,
        [request_id, replacement_admin.id]
      )
    end)
  end

  test "advances queued requests through running to completed idempotently", %{conn: conn} do
    {_student_user, student} = eligible_student()
    admin = user_fixture()
    configuration_id = insert_prompt_configuration!()
    insert_request!(admin.id, student.id, configuration_id, "completed-request")

    running_params = %{"etl_run_id" => "etl-run-624", "state" => "running"}
    running = post_status(conn, "completed-request", running_params)

    assert running == %{
             "error_code" => nil,
             "error_message" => nil,
             "etl_run_id" => "etl-run-624",
             "state" => "running"
           }

    assert post_status(conn, "completed-request", running_params) == running

    completed =
      post_status(conn, "completed-request", %{
        "etl_run_id" => "etl-run-624",
        "state" => "completed"
      })

    assert completed["state"] == "completed"

    assert post_status(conn, "completed-request", Map.put(running_params, "state", "completed")) ==
             completed

    assert Repo.query!("""
           SELECT requested_by_user_id, student_id, prompt_configuration_id, request_key, force,
                  state, etl_run_id
           FROM holistic_mentorship_regeneration_requests
           WHERE request_key = 'completed-request'
           """).rows == [
             [
               admin.id,
               student.id,
               configuration_id,
               "completed-request",
               true,
               "completed",
               "etl-run-624"
             ]
           ]
  end

  test "binds one ETL run while the request remains queued", %{conn: conn} do
    {_student_user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_request!(user_fixture().id, student.id, configuration_id, "bound-request")

    bound_params = %{"etl_run_id" => "bound-run", "state" => "queued"}

    assert post_status(conn, "bound-request", bound_params) == %{
             "error_code" => nil,
             "error_message" => nil,
             "etl_run_id" => "bound-run",
             "state" => "queued"
           }

    assert post_status(conn, "bound-request", bound_params)["etl_run_id"] == "bound-run"

    assert_status_error(
      conn,
      "bound-request",
      %{"etl_run_id" => "losing-run", "state" => "queued"},
      "etl_run_conflict"
    )

    assert_check_violation(fn ->
      Repo.query("""
      UPDATE holistic_mentorship_regeneration_requests
      SET etl_run_id = 'bypassing-run'
      WHERE request_key = 'bound-request'
      """)
    end)

    assert post_status(conn, "bound-request", %{
             "etl_run_id" => "bound-run",
             "state" => "running"
           })["state"] == "running"
  end

  test "supports failed completion and rejects regressions or ETL run conflicts", %{conn: conn} do
    {_student_user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    admin_id = user_fixture().id

    insert_request!(admin_id, student.id, configuration_id, "failed-request")
    insert_request!(admin_id, student.id, configuration_id, "queued-request")

    post_status(conn, "failed-request", %{"etl_run_id" => "etl-failed", "state" => "running"})

    assert_status_error(
      conn,
      "failed-request",
      %{"etl_run_id" => "other-run", "state" => "running"},
      "etl_run_conflict"
    )

    failed_params = %{
      "error_code" => "upstream_timeout",
      "error_message" => "Upstream generation timed out",
      "etl_run_id" => "etl-failed",
      "state" => "failed"
    }

    failed = post_status(conn, "failed-request", failed_params)
    assert failed["state"] == "failed"
    assert post_status(conn, "failed-request", failed_params) == failed

    assert_status_error(
      conn,
      "failed-request",
      %{"etl_run_id" => "etl-failed", "state" => "completed"},
      "terminal_status_conflict"
    )

    assert_status_error(
      conn,
      "queued-request",
      %{"etl_run_id" => "etl-queued", "state" => "completed"},
      "invalid_status_transition"
    )
  end

  test "a bound request can fail before its worker reaches running", %{conn: conn} do
    {_student_user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_request!(user_fixture().id, student.id, configuration_id, "pre-running-failure")

    post_status(conn, "pre-running-failure", %{
      "etl_run_id" => "pre-running-run",
      "state" => "queued"
    })

    failed_params = %{
      "error_code" => "worker_start_failed",
      "etl_run_id" => "pre-running-run",
      "state" => "failed"
    }

    assert post_status(conn, "pre-running-failure", failed_params) == %{
             "error_code" => "worker_start_failed",
             "error_message" => nil,
             "etl_run_id" => "pre-running-run",
             "state" => "failed"
           }

    assert post_status(conn, "pre-running-failure", failed_params)["state"] == "failed"

    assert_status_error(
      conn,
      "pre-running-failure",
      %{"etl_run_id" => "other-run", "state" => "failed"},
      "etl_run_conflict"
    )
  end

  test "rejects an ineligible fetch without exposing sensitive identifiers or content", %{
    conn: conn
  } do
    {student_user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_request!(user_fixture().id, student.id, configuration_id, "ineligible-request")
    Repo.query!("UPDATE student SET status = 'dropout' WHERE id = $1", [student.id])

    {response_conn, log} =
      with_debug_log(fn ->
        get(
          conn,
          "/api/holistic-mentorship/regeneration-requests/ineligible-request",
          %{
            "answers" => "private answers 624",
            "source_user_id" => "private-source-624",
            "summary" => "private summary 624"
          }
        )
      end)

    assert json_response(response_conn, 422) == %{
             "error" => %{"code" => "dropout", "message" => "Student is not eligible"}
           }

    for sensitive <- [
          Integer.to_string(student_user.id),
          Integer.to_string(student.id),
          "private answers 624",
          "private-source-624",
          "private summary 624"
        ] do
      refute response_conn.resp_body =~ sensitive
      refute log =~ sensitive
    end
  end

  test "rejects invalid and unbounded status metadata without changing the request", %{conn: conn} do
    {_student_user, student} = eligible_student()
    configuration_id = insert_prompt_configuration!()
    insert_request!(user_fixture().id, student.id, configuration_id, "invalid-request")

    for params <- [
          %{
            "error_code" => "not-allowed-while-queued",
            "etl_run_id" => "etl-invalid",
            "state" => "queued"
          },
          %{"etl_run_id" => String.duplicate("x", 256), "state" => "running"},
          %{
            "error_message" => String.duplicate("x", 501),
            "etl_run_id" => "etl-invalid",
            "state" => "failed"
          }
        ] do
      assert conn
             |> post(
               "/api/holistic-mentorship/regeneration-requests/invalid-request/status",
               params
             )
             |> json_response(422)
             |> get_in(["error", "code"]) == "invalid_request"
    end

    assert Repo.query!(
             "SELECT state, etl_run_id FROM holistic_mentorship_regeneration_requests WHERE request_key = 'invalid-request'"
           ).rows == [["queued", nil]]
  end

  test "requires the existing Bearer token for both Regeneration Request routes" do
    for authorization <- [nil, "Token malformed", "Bearer wrong-environment-secret"] do
      conn =
        if authorization,
          do: put_req_header(build_conn(), "authorization", authorization),
          else: build_conn()

      assert conn
             |> get("/api/holistic-mentorship/regeneration-requests/request-624")
             |> response(401) == "Not Authorized"

      conn =
        if authorization,
          do: put_req_header(build_conn(), "authorization", authorization),
          else: build_conn()

      assert conn
             |> post("/api/holistic-mentorship/regeneration-requests/request-624/status", %{})
             |> response(401) == "Not Authorized"
    end
  end

  defp eligible_student do
    grade = grade_fixture(%{number: 11})
    {user, student} = student_fixture(%{grade_id: grade.id, status: "active"})
    school = school_fixture(%{program_ids: [1], code: "school-#{user.id}"})

    enroll(user.id, "school", school.id)
    enroll(user.id, "grade", grade.id)

    {user, student}
  end

  defp enroll(user_id, group_type, group_id) do
    {:ok, _enrollment} =
      Dbservice.EnrollmentRecords.create_enrollment_record(%{
        user_id: user_id,
        group_id: group_id,
        group_type: group_type,
        academic_year: "2026-27",
        start_date: ~D[2026-06-01],
        is_current: true
      })
  end

  defp insert_prompt_configuration! do
    [[prompt_version_id]] =
      Repo.query!("""
      INSERT INTO holistic_mentorship_prompt_versions (version, template_text, template_hash)
      VALUES ('regeneration-v1', 'abc',
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

  defp insert_request!(admin_id, student_id, configuration_id, request_key) do
    Repo.query!(
      """
      INSERT INTO holistic_mentorship_regeneration_requests
        (request_key, requested_by_user_id, student_id, prompt_configuration_id, force, state)
      VALUES ($1, $2, $3, $4, true, 'queued')
      """,
      [request_key, admin_id, student_id, configuration_id]
    )
  end

  defp post_status(conn, request_key, params) do
    conn
    |> post("/api/holistic-mentorship/regeneration-requests/#{request_key}/status", params)
    |> json_response(200)
  end

  defp assert_status_error(conn, request_key, params, code) do
    assert conn
           |> post("/api/holistic-mentorship/regeneration-requests/#{request_key}/status", params)
           |> json_response(409)
           |> get_in(["error", "code"]) == code
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

  defp assert_check_violation(operation) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :check_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(operation.()) end, mode: :savepoint)
  end

  defp assert_unique_violation(operation) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(operation.()) end, mode: :savepoint)
  end
end
