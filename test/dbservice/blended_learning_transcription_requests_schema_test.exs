defmodule Dbservice.BlendedLearningTranscriptionRequestsSchemaTest do
  use Dbservice.DataCase, async: false

  @requests "blended_learning_transcription_requests"
  @drafts "blended_learning_conversation_drafts"

  test "defines the Transcription Request contract" do
    assert column_types(@requests) == %{
             "draft_id" => "bigint",
             "error_code" => "character varying",
             "error_message" => "text",
             "etl_run_id" => "character varying",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "request_key" => "character varying",
             "requested_by_email" => "character varying",
             "requested_by_user_id" => "bigint",
             "state" => "character varying",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns(@requests) == [
             "error_code",
             "error_message",
             "etl_run_id",
             "requested_by_user_id"
           ]

    assert column_lengths(@requests)["requested_by_email"] == 255

    assert foreign_keys(@requests) == [
             {"bl_transcription_requests_requested_by_user_id_fkey", ["requested_by_user_id"],
              "user", ["id"], "NO ACTION"},
             {"blended_learning_transcription_requests_draft_id_fkey", ["draft_id", "student_id"],
              "blended_learning_conversation_drafts", ["id", "student_id"], "NO ACTION"},
             {"blended_learning_transcription_requests_student_id_fkey", ["student_id"],
              "student", ["id"], "NO ACTION"}
           ]

    assert Repo.query!(
             """
             SELECT column_name, column_default
             FROM information_schema.columns
             WHERE table_name = $1 AND column_name IN ('state', 'inserted_at', 'updated_at')
             ORDER BY column_name
             """,
             [@requests]
           ).rows == [
             ["inserted_at", "now()"],
             ["state", "'queued'::character varying"],
             ["updated_at", "now()"]
           ]
  end

  test "names the Transcription Request CHECKs, indexes and triggers" do
    assert check_names(@requests) == [
             "bl_transcription_requests_requested_by_email_check",
             "bl_transcription_requests_safe_error_check",
             "bl_transcription_requests_state_check",
             "bl_transcription_requests_state_metadata_check"
           ]

    assert indexes(@requests) == [
             "CREATE UNIQUE INDEX bl_transcription_requests_active_draft_unique ON public.blended_learning_transcription_requests USING btree (draft_id) WHERE ((state)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[]))",
             "CREATE UNIQUE INDEX bl_transcription_requests_key_unique ON public.blended_learning_transcription_requests USING btree (request_key)",
             "CREATE UNIQUE INDEX blended_learning_transcription_requests_pkey ON public.blended_learning_transcription_requests USING btree (id)"
           ]

    assert triggers(@requests) == [
             {"bl_transcription_requests_identity_immutable",
              "blended_learning_protect_transcription_request_identity"}
           ]
  end

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
      %{state: "queued", etl_run_id: "run-bound"},
      %{state: "running", etl_run_id: "run-running"},
      %{state: "completed", etl_run_id: "run-completed"},
      %{state: "failed", etl_run_id: "run-failed"},
      %{
        state: "failed",
        etl_run_id: "run-failed-with-error",
        error_code: "upstream_timeout",
        error_message: "Transcription timed out"
      }
    ]

    for attrs <- accepted do
      draft_id = scope |> insert_draft() |> inserted_id()
      assert {:ok, _} = insert_request(scope, draft_id, attrs)
      discard_draft!(draft_id)
    end

    draft_id = scope |> insert_draft() |> inserted_id()

    for attrs <- [
          %{state: "queued", error_code: "upstream_timeout"},
          %{state: "queued", etl_run_id: "run-1", error_message: "Transcription timed out"},
          %{state: "running"},
          %{state: "running", etl_run_id: "run-1", error_code: "upstream_timeout"},
          %{state: "completed"},
          %{state: "completed", etl_run_id: "run-1", error_message: "Transcription timed out"},
          %{state: "failed"},
          %{state: "failed", error_code: "upstream_timeout"},
          %{state: "cancelled", etl_run_id: "run-1"},
          %{state: "Queued"}
        ] do
      assert_constraint(:check_violation, fn -> insert_request(scope, draft_id, attrs) end)
    end

    assert Repo.query!(
             "SELECT state, etl_run_id, error_code, error_message FROM #{@requests} ORDER BY id"
           ).rows == [
             ["queued", nil, nil, nil],
             ["queued", "run-bound", nil, nil],
             ["running", "run-running", nil, nil],
             ["completed", "run-completed", nil, nil],
             ["failed", "run-failed", nil, nil],
             ["failed", "run-failed-with-error", "upstream_timeout", "Transcription timed out"]
           ]
  end

  test "keeps Transcription Request identity immutable and binds etl_run_id only once" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()
    other_draft_id = insert_other_student_draft(scope)

    request_id =
      scope |> insert_request(draft_id, %{request_key: "identity-key"}) |> inserted_id()

    [[other_user_id]] =
      Repo.query!(
        ~s|INSERT INTO "user" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id|
      ).rows

    for {set, params} <- [
          {"request_key = 'changed-key'", []},
          {"draft_id = $2", [other_draft_id]},
          {"student_id = $2", [scope.other_student_id]},
          {"draft_id = $2, student_id = $3", [other_draft_id, scope.other_student_id]},
          {"requested_by_user_id = $2", [other_user_id]},
          {"requested_by_user_id = NULL", []},
          {"requested_by_email = 'other@example.org'", []}
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@requests} SET #{set} WHERE id = $1", [request_id | params])
      end)
    end

    assert {:ok, %{num_rows: 1}} =
             Repo.query("UPDATE #{@requests} SET etl_run_id = 'run-1' WHERE id = $1", [
               request_id
             ])

    for set <- ["etl_run_id = 'run-2'", "etl_run_id = NULL"] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@requests} SET #{set} WHERE id = $1", [request_id])
      end)
    end

    assert {:ok, %{num_rows: 1}} =
             Repo.query("UPDATE #{@requests} SET state = 'running' WHERE id = $1", [request_id])

    assert Repo.query!("""
           SELECT request_key, draft_id, student_id, requested_by_user_id, requested_by_email,
                  state, etl_run_id
           FROM #{@requests}
           """).rows == [
             [
               "identity-key",
               draft_id,
               scope.student_id,
               scope.mentor_user_id,
               "mentor@example.org",
               "running",
               "run-1"
             ]
           ]
  end

  test "bounds error_code to 1-64 chars and error_message to 1-500 chars" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()
    failed = %{state: "failed", etl_run_id: "run-1"}

    for attrs <- [
          %{error_code: ""},
          %{error_code: String.duplicate("e", 65)},
          %{error_message: ""},
          %{error_message: String.duplicate("m", 501)}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_request(scope, draft_id, Map.merge(failed, attrs))
      end)
    end

    for attrs <- [
          %{error_code: "e", error_message: "m"},
          %{error_code: String.duplicate("e", 64), error_message: String.duplicate("m", 500)}
        ] do
      assert {:ok, _} = insert_request(scope, draft_id, Map.merge(failed, attrs))
    end

    assert Repo.query!(
             "SELECT char_length(error_code), char_length(error_message) FROM #{@requests} ORDER BY id"
           ).rows == [[1, 1], [64, 500]]
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

  test "requires a nonblank requested_by_email and allows no requested_by_user_id" do
    scope = insert_scope()
    draft_id = scope |> insert_draft() |> inserted_id()

    for email <- ["", " \t"] do
      assert_constraint(:check_violation, fn ->
        insert_request(scope, draft_id, %{requested_by_email: email})
      end)
    end

    assert {:ok, _} = insert_request(scope, draft_id, %{requested_by_user_id: nil})

    assert Repo.query!("SELECT requested_by_user_id, requested_by_email FROM #{@requests}").rows ==
             [[nil, "mentor@example.org"]]
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
      recording_content_type: "audio/mp4",
      recording_byte_size: 1_048_576
    })
  end

  defp insert_other_student_draft(scope) do
    %{scope | student_id: scope.other_student_id} |> insert_draft() |> inserted_id()
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
          requested_by_user_id: scope.mentor_user_id,
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

  defp column_types(table) do
    Repo.query!(
      """
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      """,
      [table]
    ).rows
    |> Map.new(fn [name, type] -> {name, type} end)
  end

  defp nullable_columns(table) do
    Repo.query!(
      """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1 AND is_nullable = 'YES'
      ORDER BY column_name
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp column_lengths(table) do
    Repo.query!(
      """
      SELECT column_name, character_maximum_length
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
        AND character_maximum_length IS NOT NULL
      """,
      [table]
    ).rows
    |> Map.new(fn [name, length] -> {name, length} end)
  end

  defp check_names(table) do
    Repo.query!(
      """
      SELECT constraint_record.conname
      FROM pg_constraint AS constraint_record
      JOIN pg_class AS relation ON relation.oid = constraint_record.conrelid
      JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
      WHERE namespace.nspname = 'public'
        AND relation.relname = $1
        AND constraint_record.contype = 'c'
      ORDER BY constraint_record.conname
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp indexes(table) do
    Repo.query!(
      """
      SELECT indexdef
      FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = $1
      ORDER BY indexname
      """,
      [table]
    ).rows
    |> Enum.map(fn [definition] -> definition end)
  end

  defp triggers(table) do
    Repo.query!(
      """
      SELECT trigger_record.tgname, procedure.proname
      FROM pg_trigger AS trigger_record
      JOIN pg_class AS relation ON relation.oid = trigger_record.tgrelid
      JOIN pg_proc AS procedure ON procedure.oid = trigger_record.tgfoid
      WHERE relation.relname = $1 AND NOT trigger_record.tgisinternal
      ORDER BY trigger_record.tgname
      """,
      [table]
    ).rows
    |> Enum.map(&List.to_tuple/1)
  end

  defp foreign_keys(table) do
    Repo.query!(
      """
      SELECT constraint_record.conname,
             ARRAY(
               SELECT attribute.attname
               FROM unnest(constraint_record.conkey) WITH ORDINALITY AS key(attnum, ordinality)
               JOIN pg_attribute AS attribute
                 ON attribute.attrelid = constraint_record.conrelid
                AND attribute.attnum = key.attnum
               ORDER BY key.ordinality
             ),
             referenced.relname,
             ARRAY(
               SELECT attribute.attname
               FROM unnest(constraint_record.confkey) WITH ORDINALITY AS key(attnum, ordinality)
               JOIN pg_attribute AS attribute
                 ON attribute.attrelid = constraint_record.confrelid
                AND attribute.attnum = key.attnum
               ORDER BY key.ordinality
             ),
             CASE constraint_record.confdeltype
               WHEN 'a' THEN 'NO ACTION'
               WHEN 'r' THEN 'RESTRICT'
               WHEN 'c' THEN 'CASCADE'
               WHEN 'n' THEN 'SET NULL'
               WHEN 'd' THEN 'SET DEFAULT'
             END
      FROM pg_constraint AS constraint_record
      JOIN pg_class AS relation ON relation.oid = constraint_record.conrelid
      JOIN pg_class AS referenced ON referenced.oid = constraint_record.confrelid
      JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
      WHERE namespace.nspname = 'public'
        AND relation.relname = $1
        AND constraint_record.contype = 'f'
      ORDER BY constraint_record.conname
      """,
      [table]
    ).rows
    |> Enum.map(&List.to_tuple/1)
  end
end
