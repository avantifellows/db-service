defmodule Dbservice.BlendedLearningTranscriptionRequestsSchemaTest do
  use Dbservice.DataCase, async: false

  @requests "blended_learning_transcription_requests"
  @drafts "blended_learning_conversation_drafts"

  test "allows one queued or running Transcription Request per draft and a retry after failure" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()

    request_id = scope |> insert_request(draft_id, %{request_key: "first"}) |> inserted_id()

    assert_constraint(:unique_violation, fn ->
      insert_request(scope, draft_id, %{request_key: "second-queued"})
    end)

    Repo.query!(
      "UPDATE #{@requests} SET state = 'running', etl_run_id = 'run-1' WHERE id = $1",
      [request_id]
    )

    assert_constraint(:unique_violation, fn ->
      insert_request(scope, draft_id, %{request_key: "second-while-running"})
    end)

    Repo.query!("UPDATE #{@requests} SET state = 'failed' WHERE id = $1", [request_id])

    assert {:ok, _} = insert_request(scope, draft_id, %{request_key: "retry"})

    assert Repo.query!(
             "SELECT request_key, state FROM #{@requests} WHERE draft_id = $1 ORDER BY id",
             [draft_id]
           ).rows == [["first", "failed"], ["retry", "queued"]]
  end

  test "ties run and error metadata to each Transcription Request state" do
    scope = insert_scope()

    accepted = [
      %{state: "queued"},
      %{state: "running", etl_run_id: "run-running"},
      %{state: "completed", etl_run_id: "run-completed"},
      %{state: "failed", etl_run_id: "run-failed"},
      %{state: "failed", etl_run_id: "run-failed-with-error", error_code: "upstream_timeout"}
    ]

    for attrs <- accepted do
      draft_id = scope |> insert_draft() |> inserted_id()
      assert {:ok, _} = insert_request(scope, draft_id, attrs)
      discard_draft!(draft_id)
    end

    draft_id = scope |> insert_draft() |> inserted_id()

    for attrs <- [
          %{state: "queued", etl_run_id: "run-1"},
          %{state: "queued", error_code: "upstream_timeout"},
          %{state: "running"},
          %{state: "running", etl_run_id: "run-1", error_code: "upstream_timeout"},
          %{state: "completed"},
          %{state: "completed", etl_run_id: "run-1", error_code: "upstream_timeout"},
          %{state: "failed"},
          %{state: "failed", error_code: "upstream_timeout"},
          %{state: "cancelled", etl_run_id: "run-1"},
          %{state: "Queued"}
        ] do
      assert_constraint(:check_violation, fn -> insert_request(scope, draft_id, attrs) end)
    end

    assert Repo.query!("SELECT state, etl_run_id, error_code FROM #{@requests} ORDER BY id").rows ==
             [
               ["queued", nil, nil],
               ["running", "run-running", nil],
               ["completed", "run-completed", nil],
               ["failed", "run-failed", nil],
               ["failed", "run-failed-with-error", "upstream_timeout"]
             ]
  end

  test "bounds error_code to 1-64 chars" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()
    failed = %{state: "failed", etl_run_id: "run-1"}

    for error_code <- ["", String.duplicate("e", 65)] do
      assert_constraint(:check_violation, fn ->
        insert_request(scope, draft_id, Map.put(failed, :error_code, error_code))
      end)
    end

    for error_code <- ["e", String.duplicate("e", 64)] do
      assert {:ok, _} = insert_request(scope, draft_id, Map.put(failed, :error_code, error_code))
    end

    assert Repo.query!("SELECT char_length(error_code) FROM #{@requests} ORDER BY id").rows ==
             [[1], [64]]
  end

  test "rejects a duplicate request_key" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()

    assert {:ok, _} =
             insert_request(scope, draft_id, %{
               request_key: "dup-key",
               state: "failed",
               etl_run_id: "run-1"
             })

    assert_constraint(:unique_violation, fn ->
      insert_request(scope, draft_id, %{request_key: "dup-key"})
    end)

    assert Repo.query!("SELECT count(*) FROM #{@requests}").rows == [[1]]
  end

  test "requires a nonblank requested_by_email" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()

    for email <- ["", " \t"] do
      assert_constraint(:check_violation, fn ->
        insert_request(scope, draft_id, %{requested_by_email: email})
      end)
    end

    assert {:ok, _} = insert_request(scope, draft_id, %{})

    assert Repo.query!("SELECT requested_by_email FROM #{@requests}").rows == [
             ["mentor@example.org"]
           ]
  end

  test "rejects a Student that does not own the draft" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()

    assert_constraint(:foreign_key_violation, fn ->
      insert_request(scope, draft_id, %{student_id: scope.other_student_id})
    end)

    assert Repo.query!("SELECT count(*) FROM #{@requests}").rows == [[0]]
  end

  defp insert_scope do
    [[student_user_id], [other_student_user_id], [mentor_user_id]] =
      Repo.query!("""
      INSERT INTO "user" (inserted_at, updated_at)
      VALUES (now(), now()), (now(), now()), (now(), now())
      RETURNING id
      """).rows

    [[student_id], [other_student_id]] =
      Repo.query!(
        """
        INSERT INTO student (user_id, inserted_at, updated_at)
        VALUES ($1, now(), now()), ($2, now(), now())
        RETURNING id
        """,
        [student_user_id, other_student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Transcription', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Transcription', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_draft(scope) do
    insert_row(@drafts, %{
      student_id: scope.student_id,
      program_id: scope.program_id,
      mentor_user_id: scope.mentor_user_id,
      academic_year: "2026-2027",
      created_by_email: "mentor@example.org",
      state: "transcribing",
      call_recording_s3_key: "blended-learning/recordings/1.m4a",
      recording_content_type: "audio/mp4"
    })
  end

  defp discard_draft!(draft_id) do
    Repo.query!(
      "UPDATE #{@drafts} SET state = 'discarded', discarded_at = now() WHERE id = $1",
      [draft_id]
    )
  end

  defp insert_request(scope, draft_id, attrs) do
    insert_row(
      @requests,
      Map.merge(
        %{
          request_key: "transcription-#{System.unique_integer([:positive])}",
          draft_id: draft_id,
          student_id: scope.student_id,
          requested_by_email: "mentor@example.org"
        },
        attrs
      )
    )
  end

  defp inserted_id({:ok, %{rows: [[id]]}}), do: id

  defp insert_row(table, attrs) do
    {columns, values} = attrs |> Enum.sort() |> Enum.unzip()
    placeholders = Enum.map_join(1..length(values), ", ", &"$#{&1}")

    Repo.query(
      "INSERT INTO #{table} (#{Enum.join(columns, ", ")}) VALUES (#{placeholders}) RETURNING id",
      values
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
