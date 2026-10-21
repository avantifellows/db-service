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

  test "keeps the request key and draft content out of debug logs", %{conn: conn} do
    scope = insert_scope("Female")
    insert_request!(scope, insert_draft!(scope), "secret-request-801")

    {response_conn, log} =
      with_debug_log(fn ->
        get(conn, "/api/blended-learning/transcription-requests/secret-request-801")
      end)

    assert json_response(response_conn, 200)["request_key"] == "secret-request-801"

    for sensitive <- ["secret-request-801", "blended-learning/recordings/801.mp3", "audio/mpeg"] do
      refute log =~ sensitive
    end
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
          (student_id, program_id, academic_year, mentor_user_id, created_by_user_id,
           created_by_email, state, occurred_on, mode, spoke_with, duration_minutes,
           call_recording_s3_key, recording_content_type, recording_byte_size)
        VALUES ($1, $2, '2026-2027', $3, $3, 'mentor.private@example.org', 'transcribing',
                '2026-10-20', 'call', 'student', 25, 'blended-learning/recordings/801.mp3',
                'audio/mpeg', 2097152)
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
        (request_key, draft_id, student_id, requested_by_user_id, requested_by_email)
      VALUES ($1, $2, $3, $4, 'mentor.private@example.org')
      """,
      [request_key, draft_id, scope.student_id, scope.mentor_user_id]
    )
  end
end
