defmodule DbserviceWeb.HolisticMentorshipPromptConfigurationControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import ExUnit.CaptureLog

  @template_hash "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

  test "registers an inactive Prompt Configuration after verifying its template hash", %{
    conn: conn
  } do
    response =
      conn
      |> post("/api/holistic-mentorship/prompt-configurations", %{
        "prompt_version" => "profile-v1",
        "template_text" => "abc",
        "template_hash" => @template_hash,
        "model_id" => "openai/gpt-5-mini"
      })
      |> json_response(200)

    assert response == %{
             "id" => response["id"],
             "model_id" => "openai/gpt-5-mini",
             "prompt_version" => "profile-v1",
             "state" => "inactive",
             "template_hash" => @template_hash
           }

    assert Repo.query!("""
           SELECT version, template_text, template_hash, model_id, state
           FROM holistic_mentorship_prompt_versions AS version
           JOIN holistic_mentorship_prompt_configurations AS configuration
             ON configuration.prompt_version_id = version.id
           """).rows == [
             ["profile-v1", "abc", @template_hash, "openai/gpt-5-mini", "inactive"]
           ]
  end

  test "rejects a mismatched template hash without exposing the template", %{conn: conn} do
    template_text = "sensitive template text"

    {conn, log} =
      with_debug_log(fn ->
        post(conn, "/api/holistic-mentorship/prompt-configurations", %{
          "prompt_version" => "profile-v1",
          "template_text" => template_text,
          "template_hash" => String.duplicate("0", 64),
          "model_id" => "openai/gpt-5-mini"
        })
      end)

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "template_hash_mismatch",
               "message" => "Template hash does not match template text"
             }
           }

    refute conn.resp_body =~ template_text
    refute log =~ template_text
  end

  test "rejects different content for an existing Prompt Version without exposing it", %{
    conn: conn
  } do
    register(conn)
    conflicting_text = "abcd"

    {conn, log} =
      with_debug_log(fn ->
        post(conn, "/api/holistic-mentorship/prompt-configurations", %{
          "prompt_version" => "profile-v1",
          "template_text" => conflicting_text,
          "template_hash" => "88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589",
          "model_id" => "anthropic/claude-sonnet"
        })
      end)

    assert json_response(conn, 409) == %{
             "error" => %{
               "code" => "prompt_version_conflict",
               "message" => "Prompt Version already exists with different content"
             }
           }

    refute conn.resp_body =~ conflicting_text
    refute log =~ conflicting_text

    assert Repo.query!(
             "SELECT template_text, template_hash FROM holistic_mentorship_prompt_versions"
           ).rows == [["abc", @template_hash]]
  end

  test "retries idempotently and registers distinct inactive model configurations", %{conn: conn} do
    first = register(conn) |> json_response(200)
    retry = register(conn) |> json_response(200)

    second =
      register(conn, %{"model_id" => "anthropic/claude-sonnet"})
      |> json_response(200)

    assert retry == first
    refute second["id"] == first["id"]

    assert Repo.query!("""
           SELECT version, model_id, state
           FROM holistic_mentorship_prompt_versions AS version
           JOIN holistic_mentorship_prompt_configurations AS configuration
             ON configuration.prompt_version_id = version.id
           ORDER BY model_id
           """).rows == [
             ["profile-v1", "anthropic/claude-sonnet", "inactive"],
             ["profile-v1", "openai/gpt-5-mini", "inactive"]
           ]
  end

  test "explicit activation switches the single Active configuration idempotently", %{conn: conn} do
    first = register(conn) |> json_response(200)

    second =
      register(conn, %{"model_id" => "anthropic/claude-sonnet"})
      |> json_response(200)

    assert activate(conn, first["id"])["state"] == "active"
    assert activate(conn, second["id"]) == activate(conn, second["id"])

    assert Repo.query!(
             "SELECT id, state FROM holistic_mentorship_prompt_configurations ORDER BY id"
           ).rows == [
             [first["id"], "inactive"],
             [second["id"], "active"]
           ]
  end

  test "rejects malformed registration with a safe machine error", %{conn: conn} do
    conn =
      post(conn, "/api/holistic-mentorship/prompt-configurations", %{
        "prompt_version" => "profile-v1",
        "template_hash" => @template_hash,
        "model_id" => "openai/gpt-5-mini"
      })

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Required prompt configuration fields are missing or invalid"
             }
           }
  end

  test "rejects unknown activation targets with a stable safe error", %{conn: conn} do
    conn = post(conn, "/api/holistic-mentorship/prompt-configurations/999999/activate", %{})

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "prompt_configuration_not_found",
               "message" => "Prompt Configuration not found"
             }
           }
  end

  test "requires the existing Bearer token while health remains public" do
    for authorization <- [
          nil,
          "Token malformed",
          "Bearer wrong-token",
          "Bearer production-test-token"
        ] do
      request_conn = build_conn()

      request_conn =
        if authorization,
          do: put_req_header(request_conn, "authorization", authorization),
          else: request_conn

      assert request_conn
             |> post("/api/holistic-mentorship/prompt-configurations", %{})
             |> response(401) == "Not Authorized"
    end

    assert build_conn() |> get("/api/health") |> json_response(200) == %{"status" => "ok"}
    assert build_conn() |> get("/api/health/ready") |> json_response(200) == %{"status" => "ok"}
  end

  test "serializes concurrent activation and leaves exactly one configuration Active", %{
    conn: conn
  } do
    authorization = conn |> get_req_header("authorization") |> List.first()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      first = register(build_conn(authorization)) |> json_response(200)

      second =
        register(build_conn(authorization), %{"model_id" => "anthropic/claude-sonnet"})
        |> json_response(200)

      try do
        parent = self()

        tasks =
          for id <- [first["id"], second["id"]] do
            Task.async(fn ->
              Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})
                receive do: (:go -> activate(build_conn(authorization), id))
              end)
            end)
          end

        task_pids =
          for _ <- tasks do
            assert_receive {:ready, task_pid}
            task_pid
          end

        Enum.each(task_pids, &send(&1, :go))
        assert Enum.map(tasks, &Task.await/1) |> Enum.all?(&(&1["state"] == "active"))

        assert Repo.query!(
                 "SELECT count(*) FROM holistic_mentorship_prompt_configurations WHERE state = 'active'"
               ).rows == [[1]]
      after
        Repo.query!(
          "TRUNCATE holistic_mentorship_student_profile_summaries, holistic_mentorship_student_profiles, holistic_mentorship_prompt_configurations, holistic_mentorship_prompt_versions RESTART IDENTITY"
        )
      end
    end)
  end

  test "database rows keep Prompt Version and model configuration content immutable", %{
    conn: conn
  } do
    configuration = register(conn) |> json_response(200)

    assert_check_violation(fn ->
      Repo.query(
        "UPDATE holistic_mentorship_prompt_versions SET template_text = 'changed' WHERE version = 'profile-v1'"
      )
    end)

    assert_check_violation(fn ->
      Repo.query(
        "UPDATE holistic_mentorship_prompt_configurations SET model_id = 'changed' WHERE id = $1",
        [configuration["id"]]
      )
    end)
  end

  defp register(conn, overrides \\ %{}) do
    params =
      Map.merge(
        %{
          "prompt_version" => "profile-v1",
          "template_text" => "abc",
          "template_hash" => @template_hash,
          "model_id" => "openai/gpt-5-mini"
        },
        overrides
      )

    post(conn, "/api/holistic-mentorship/prompt-configurations", params)
  end

  defp activate(conn, id) do
    conn
    |> post("/api/holistic-mentorship/prompt-configurations/#{id}/activate", %{})
    |> json_response(200)
  end

  defp build_conn(authorization) do
    build_conn() |> put_req_header("authorization", authorization)
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
end
