defmodule Dbservice.BlendedLearningConversationsSchemaTest do
  use Dbservice.DataCase, async: false

  @conversations "blended_learning_conversations"
  @drafts "blended_learning_conversation_drafts"

  @conversation %{
    kind: "conversation",
    academic_year: "2026-2027",
    logged_by_email: "ops@example.org",
    occurred_on: ~D[2026-10-20],
    mode: "call",
    spoke_with: "student",
    duration_minutes: 25,
    summary: "Discussed the mock test plan.",
    notes_html: "<p>Physics revision twice a week.</p>"
  }

  @attempt %{
    kind: "attempt",
    academic_year: "2026-2027",
    logged_by_email: "ops@example.org",
    occurred_on: ~D[2026-10-19]
  }

  @ready_fields %{
    draft_summary: "Discussed the mock test plan.",
    transcript_s3_key: "blended-learning/transcripts/1.json",
    prompt_version: "bl-draft-v1",
    model_id: "gemini-2.5-pro",
    ready_at: ~N[2026-10-20 10:05:00]
  }

  test "defines the Conversation contract" do
    assert column_types(@conversations) == %{
             "academic_year" => "character varying",
             "attempt_note" => "text",
             "call_recording_s3_key" => "text",
             "duration_minutes" => "integer",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "kind" => "character varying",
             "logged_by_email" => "character varying",
             "logged_by_user_id" => "bigint",
             "mentor_user_id" => "bigint",
             "mode" => "character varying",
             "notes_html" => "text",
             "occurred_on" => "date",
             "program_id" => "bigint",
             "source_draft_id" => "bigint",
             "spoke_with" => "character varying",
             "student_id" => "bigint",
             "summary" => "text",
             "transcript_s3_key" => "text"
           }

    assert nullable_columns(@conversations) == [
             "attempt_note",
             "call_recording_s3_key",
             "duration_minutes",
             "logged_by_user_id",
             "mode",
             "notes_html",
             "source_draft_id",
             "spoke_with",
             "summary",
             "transcript_s3_key"
           ]

    assert column_lengths(@conversations)["logged_by_email"] == 255

    assert foreign_keys(@conversations) == [
             {"blended_learning_conversations_logged_by_user_id_fkey", ["logged_by_user_id"],
              "user", ["id"], "NO ACTION"},
             {"blended_learning_conversations_mentor_user_id_fkey", ["mentor_user_id"], "user",
              ["id"], "NO ACTION"},
             {"blended_learning_conversations_program_id_fkey", ["program_id"], "program", ["id"],
              "NO ACTION"},
             {"blended_learning_conversations_source_draft_id_fkey",
              ["source_draft_id", "student_id"], "blended_learning_conversation_drafts",
              ["id", "student_id"], "NO ACTION"},
             {"blended_learning_conversations_student_id_fkey", ["student_id"], "student", ["id"],
              "NO ACTION"}
           ]
  end

  test "names the Conversation and Draft CHECKs, indexes and triggers" do
    assert check_names(@conversations) == [
             "bl_conversations_academic_year_check",
             "bl_conversations_attempt_note_check",
             "bl_conversations_call_recording_s3_key_check",
             "bl_conversations_duration_minutes_check",
             "bl_conversations_kind_check",
             "bl_conversations_kind_fields_check",
             "bl_conversations_logged_by_email_check",
             "bl_conversations_mode_check",
             "bl_conversations_spoke_with_check",
             "bl_conversations_transcript_s3_key_check"
           ]

    assert check_names(@drafts) == [
             "bl_conversation_drafts_academic_year_check",
             "bl_conversation_drafts_call_recording_s3_key_check",
             "bl_conversation_drafts_created_by_email_check",
             "bl_conversation_drafts_discarded_check",
             "bl_conversation_drafts_draft_action_items_check",
             "bl_conversation_drafts_draft_items_to_verify_check",
             "bl_conversation_drafts_draft_notes_check",
             "bl_conversation_drafts_draft_summary_tags_check",
             "bl_conversation_drafts_duration_minutes_check",
             "bl_conversation_drafts_mode_check",
             "bl_conversation_drafts_ready_check",
             "bl_conversation_drafts_recording_byte_size_check",
             "bl_conversation_drafts_recording_content_type_check",
             "bl_conversation_drafts_saved_check",
             "bl_conversation_drafts_spoke_with_check",
             "bl_conversation_drafts_state_check"
           ]

    assert indexes(@conversations) == [
             "CREATE UNIQUE INDEX bl_conversations_id_student_unique ON public.blended_learning_conversations USING btree (id, student_id)",
             "CREATE INDEX bl_conversations_mentor_year_idx ON public.blended_learning_conversations USING btree (mentor_user_id, academic_year)",
             "CREATE UNIQUE INDEX bl_conversations_source_draft_unique ON public.blended_learning_conversations USING btree (source_draft_id) WHERE (source_draft_id IS NOT NULL)",
             "CREATE INDEX bl_conversations_student_timeline_idx ON public.blended_learning_conversations USING btree (student_id, occurred_on DESC, id DESC)",
             "CREATE UNIQUE INDEX blended_learning_conversations_pkey ON public.blended_learning_conversations USING btree (id)"
           ]

    assert indexes(@drafts) == [
             "CREATE UNIQUE INDEX bl_conversation_drafts_id_student_unique ON public.blended_learning_conversation_drafts USING btree (id, student_id)",
             "CREATE UNIQUE INDEX bl_conversation_drafts_open_student_unique ON public.blended_learning_conversation_drafts USING btree (student_id) WHERE ((state)::text = ANY ((ARRAY['transcribing'::character varying, 'ready'::character varying, 'failed'::character varying])::text[]))",
             "CREATE UNIQUE INDEX blended_learning_conversation_drafts_pkey ON public.blended_learning_conversation_drafts USING btree (id)"
           ]

    assert triggers(@conversations) == [
             {"bl_conversations_immutable", "blended_learning_protect_conversation"}
           ]

    assert triggers(@drafts) == []
  end

  test "provides the shared kind-rule trigger function for records attached to Conversations" do
    assert Repo.query!("""
           SELECT procedure.proname, return_type.typname, language.lanname
           FROM pg_proc AS procedure
           JOIN pg_namespace AS namespace ON namespace.oid = procedure.pronamespace
           JOIN pg_type AS return_type ON return_type.oid = procedure.prorettype
           JOIN pg_language AS language ON language.oid = procedure.prolang
           WHERE namespace.nspname = 'public'
             AND procedure.proname = 'blended_learning_reject_attempt_reference'
           """).rows == [["blended_learning_reject_attempt_reference", "trigger", "plpgsql"]]
  end

  test "accepts a complete Conversation and an Attempt with only a date and an optional note" do
    scope = insert_scope()

    assert {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    assert {:ok, %{rows: [[attempt_id]]}} = insert_attempt(scope, %{})

    assert {:ok, %{rows: [[noted_attempt_id]]}} =
             insert_attempt(scope, %{attempt_note: "Phone switched off."})

    assert Repo.query!(
             """
             SELECT id, kind, mode, spoke_with, duration_minutes, summary, attempt_note
             FROM #{@conversations} WHERE student_id = $1 ORDER BY id
             """,
             [scope.student_id]
           ).rows == [
             [
               conversation_id,
               "conversation",
               "call",
               "student",
               25,
               "Discussed the mock test plan.",
               nil
             ],
             [attempt_id, "attempt", nil, nil, nil, nil, nil],
             [noted_attempt_id, "attempt", nil, nil, nil, nil, "Phone switched off."]
           ]
  end

  test "rejects an Attempt carrying any Conversation field" do
    scope = insert_scope()

    {:ok, %{rows: [[draft_id]]}} =
      insert_draft(scope, %{state: "discarded", discarded_at: ~N[2026-10-20 10:00:00]})

    for field <- [
          %{mode: "call"},
          %{spoke_with: "parent_or_sibling"},
          %{duration_minutes: 10},
          %{summary: "Did not connect."},
          %{notes_html: "<p>Busy.</p>"},
          %{call_recording_s3_key: "blended-learning/recordings/1.m4a"},
          %{transcript_s3_key: "blended-learning/transcripts/1.json"},
          %{source_draft_id: draft_id}
        ] do
      assert_constraint(:check_violation, fn -> insert_attempt(scope, field) end)
    end
  end

  test "rejects an incomplete Conversation, a Conversation with an attempt note, and blank text" do
    scope = insert_scope()

    for field <- [
          %{mode: nil},
          %{spoke_with: nil},
          %{duration_minutes: nil},
          %{summary: nil},
          %{summary: ""},
          %{summary: " \n\t"},
          %{attempt_note: "Also tried earlier."}
        ] do
      assert_constraint(:check_violation, fn -> insert_conversation(scope, field) end)
    end

    for note <- ["", "   "] do
      assert_constraint(:check_violation, fn -> insert_attempt(scope, %{attempt_note: note}) end)
    end
  end

  test "defines the Conversation Draft contract" do
    assert column_types(@drafts) == %{
             "academic_year" => "character varying",
             "call_recording_s3_key" => "text",
             "created_by_email" => "character varying",
             "created_by_user_id" => "bigint",
             "detected_language" => "character varying",
             "discarded_at" => "timestamp without time zone",
             "draft_action_items" => "jsonb",
             "draft_items_to_verify" => "jsonb",
             "draft_notes" => "jsonb",
             "draft_summary" => "text",
             "draft_summary_tags" => "ARRAY",
             "duration_minutes" => "integer",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "mentor_user_id" => "bigint",
             "mode" => "character varying",
             "model_id" => "character varying",
             "occurred_on" => "date",
             "program_id" => "bigint",
             "prompt_version" => "character varying",
             "ready_at" => "timestamp without time zone",
             "recording_byte_size" => "bigint",
             "recording_content_type" => "character varying",
             "saved_conversation_id" => "bigint",
             "spoke_with" => "character varying",
             "state" => "character varying",
             "student_id" => "bigint",
             "transcript_s3_key" => "text",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns(@drafts) == [
             "created_by_user_id",
             "detected_language",
             "discarded_at",
             "draft_action_items",
             "draft_items_to_verify",
             "draft_notes",
             "draft_summary",
             "draft_summary_tags",
             "duration_minutes",
             "mode",
             "model_id",
             "occurred_on",
             "prompt_version",
             "ready_at",
             "saved_conversation_id",
             "spoke_with",
             "transcript_s3_key"
           ]

    assert column_lengths(@drafts)["created_by_email"] == 255

    assert foreign_keys(@drafts) == [
             {"blended_learning_conversation_drafts_created_by_user_id_fkey",
              ["created_by_user_id"], "user", ["id"], "NO ACTION"},
             {"blended_learning_conversation_drafts_mentor_user_id_fkey", ["mentor_user_id"],
              "user", ["id"], "NO ACTION"},
             {"blended_learning_conversation_drafts_program_id_fkey", ["program_id"], "program",
              ["id"], "NO ACTION"},
             {"blended_learning_conversation_drafts_saved_conversation_id_fkey",
              ["saved_conversation_id", "student_id"], "blended_learning_conversations",
              ["id", "student_id"], "NO ACTION"},
             {"blended_learning_conversation_drafts_student_id_fkey", ["student_id"], "student",
              ["id"], "NO ACTION"}
           ]
  end

  test "accepts durations of 1 to 240 minutes and only known kinds, modes and people" do
    scope = insert_scope()

    for minutes <- [0, 241, -5] do
      assert_constraint(:check_violation, fn ->
        insert_conversation(scope, %{duration_minutes: minutes})
      end)
    end

    for minutes <- [1, 240] do
      assert {:ok, _} = insert_conversation(scope, %{duration_minutes: minutes})
    end

    for field <- [%{kind: "missed_call"}, %{mode: "video"}, %{spoke_with: "teacher"}] do
      assert_constraint(:check_violation, fn -> insert_conversation(scope, field) end)
    end

    for mode <- ["call", "in_person"], spoke_with <- ["student", "parent_or_sibling", "both"] do
      assert {:ok, _} = insert_conversation(scope, %{mode: mode, spoke_with: spoke_with})
    end
  end

  test "rejects a blank academic year, logger email or S3 key on a Conversation" do
    scope = insert_scope()

    for field <- [
          %{academic_year: ""},
          %{academic_year: "  "},
          %{logged_by_email: ""},
          %{logged_by_email: " "},
          %{call_recording_s3_key: ""},
          %{call_recording_s3_key: " "},
          %{transcript_s3_key: ""},
          %{transcript_s3_key: "\t"}
        ] do
      assert_constraint(:check_violation, fn -> insert_conversation(scope, field) end)
    end

    assert {:ok, _} =
             insert_conversation(scope, %{
               call_recording_s3_key: "blended-learning/recordings/1.m4a",
               transcript_s3_key: "blended-learning/transcripts/1.json"
             })
  end

  test "rejects every UPDATE and DELETE of a Conversation or Attempt" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[attempt_id]]}} = insert_attempt(scope, %{attempt_note: "No answer."})

    for id <- [conversation_id, attempt_id],
        statement <- [
          "UPDATE #{@conversations} SET occurred_on = occurred_on WHERE id = $1",
          "UPDATE #{@conversations} SET logged_by_email = 'other@example.org' WHERE id = $1",
          "DELETE FROM #{@conversations} WHERE id = $1"
        ] do
      assert_constraint(:check_violation, fn -> Repo.query(statement, [id]) end)
    end

    assert Repo.query!(
             "SELECT id, logged_by_email FROM #{@conversations} WHERE student_id = $1 ORDER BY id",
             [scope.student_id]
           ).rows == [
             [conversation_id, "ops@example.org"],
             [attempt_id, "ops@example.org"]
           ]
  end

  test "saves a Conversation Draft into at most one Conversation of the same Student" do
    scope = insert_scope()
    {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, %{})

    assert {:ok, _} = insert_conversation(scope, %{source_draft_id: draft_id})

    assert_constraint(:unique_violation, fn ->
      insert_conversation(scope, %{source_draft_id: draft_id})
    end)

    other_scope = %{scope | student_id: scope.other_student_id}
    {:ok, %{rows: [[other_draft_id]]}} = insert_draft(other_scope, %{})

    assert_constraint(:foreign_key_violation, fn ->
      insert_conversation(scope, %{source_draft_id: other_draft_id})
    end)

    assert {:ok, _} = insert_conversation(scope, %{source_draft_id: nil})
    assert {:ok, _} = insert_conversation(scope, %{source_draft_id: nil})
  end

  test "points a saved Conversation Draft only at a Conversation of the same Student" do
    scope = insert_scope()
    {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, %{})

    other_scope = %{scope | student_id: scope.other_student_id}
    {:ok, %{rows: [[other_conversation_id]]}} = insert_conversation(other_scope, %{})

    assert_constraint(:foreign_key_violation, fn ->
      Repo.query(
        "UPDATE #{@drafts} SET saved_conversation_id = $1 WHERE id = $2",
        [other_conversation_id, draft_id]
      )
    end)

    {:ok, %{rows: [[conversation_id]]}} =
      insert_conversation(scope, %{source_draft_id: draft_id})

    Repo.query!(
      "UPDATE #{@drafts} SET state = 'saved', saved_conversation_id = $1 WHERE id = $2",
      [conversation_id, draft_id]
    )

    assert Repo.query!(
             "SELECT state, saved_conversation_id FROM #{@drafts} WHERE id = $1",
             [draft_id]
           ).rows == [["saved", conversation_id]]
  end

  test "allows a Student at most one open Conversation Draft" do
    scope = insert_scope()
    other_scope = %{scope | student_id: scope.other_student_id}
    assert {:ok, _} = insert_draft(other_scope, %{})

    for open_state <- ["transcribing", "ready", "failed"] do
      {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, open_state_attrs(open_state))

      for second_state <- ["transcribing", "ready", "failed"] do
        assert_constraint(:unique_violation, fn ->
          insert_draft(scope, open_state_attrs(second_state))
        end)
      end

      Repo.query!(
        "UPDATE #{@drafts} SET state = 'discarded', discarded_at = now() WHERE id = $1",
        [draft_id]
      )
    end

    {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, %{})
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{source_draft_id: draft_id})

    Repo.query!(
      "UPDATE #{@drafts} SET state = 'saved', saved_conversation_id = $1 WHERE id = $2",
      [conversation_id, draft_id]
    )

    assert {:ok, _} = insert_draft(scope, %{})

    assert Repo.query!(
             "SELECT state, count(*) FROM #{@drafts} WHERE student_id = $1 GROUP BY state ORDER BY state",
             [scope.student_id]
           ).rows == [["discarded", 3], ["saved", 1], ["transcribing", 1]]
  end

  test "requires the drafted content before a Conversation Draft is ready" do
    scope = insert_scope()

    for missing <- [
          %{draft_summary: nil},
          %{draft_summary: ""},
          %{draft_summary: " \n"},
          %{transcript_s3_key: nil},
          %{prompt_version: nil},
          %{model_id: nil},
          %{ready_at: nil}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_draft(scope, open_state_attrs("ready") |> Map.merge(missing))
      end)
    end

    assert {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, open_state_attrs("ready"))

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@drafts} SET ready_at = NULL WHERE id = $1", [draft_id])
    end)
  end

  test "requires a saved Conversation for saved drafts and a time for discarded drafts" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn -> insert_draft(scope, %{state: "saved"}) end)
    assert_constraint(:check_violation, fn -> insert_draft(scope, %{state: "discarded"}) end)
    assert_constraint(:check_violation, fn -> insert_draft(scope, %{state: "archived"}) end)

    assert {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, %{})

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@drafts} SET state = 'saved' WHERE id = $1", [draft_id])
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@drafts} SET state = 'discarded' WHERE id = $1", [draft_id])
    end)

    assert {:ok, _} =
             insert_draft(scope, %{state: "discarded", discarded_at: ~N[2026-10-20 11:00:00]})
  end

  test "limits drafted tags to four and drafted lists to JSON arrays" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn ->
      insert_draft(scope, %{draft_summary_tags: ["exam", "family", "health", "fees", "travel"]})
    end)

    for column <- [:draft_action_items, :draft_notes, :draft_items_to_verify],
        value <- [%{"text" => "Revise optics"}, "Revise optics", 3] do
      assert_constraint(:check_violation, fn -> insert_draft(scope, %{column => value}) end)
    end

    assert {:ok, %{rows: [[draft_id]]}} =
             insert_draft(scope, %{
               draft_summary_tags: ["exam", "family", "health", "fees"],
               draft_action_items: [
                 %{"text" => "Revise optics", "owner" => "student", "due_on" => nil}
               ],
               draft_notes: [%{"heading" => "Studies", "points" => ["Physics is weak"]}],
               draft_items_to_verify: []
             })

    assert Repo.query!(
             """
             SELECT draft_summary_tags, draft_action_items, draft_notes, draft_items_to_verify
             FROM #{@drafts} WHERE id = $1
             """,
             [draft_id]
           ).rows == [
             [
               ["exam", "family", "health", "fees"],
               [%{"due_on" => nil, "owner" => "student", "text" => "Revise optics"}],
               [%{"heading" => "Studies", "points" => ["Physics is weak"]}],
               []
             ]
           ]
  end

  test "requires an audio Call Recording with a positive size and valid session details" do
    scope = insert_scope()

    for field <- [
          %{recording_content_type: "video/mp4"},
          %{recording_content_type: "application/octet-stream"},
          %{recording_content_type: " audio/mp4"},
          %{recording_byte_size: 0},
          %{recording_byte_size: -1},
          %{call_recording_s3_key: ""},
          %{call_recording_s3_key: "  "},
          %{academic_year: " "},
          %{created_by_email: ""},
          %{mode: "video"},
          %{spoke_with: "teacher"},
          %{duration_minutes: 0},
          %{duration_minutes: 241}
        ] do
      assert_constraint(:check_violation, fn -> insert_draft(scope, field) end)
    end

    assert {:ok, %{rows: [[draft_id]]}} =
             insert_draft(scope, %{
               recording_content_type: "audio/mpeg",
               recording_byte_size: 1,
               occurred_on: ~D[2026-10-20],
               mode: "in_person",
               spoke_with: "both",
               duration_minutes: 240
             })

    Repo.query!(
      "UPDATE #{@drafts} SET state = 'discarded', discarded_at = now() WHERE id = $1",
      [draft_id]
    )

    assert {:ok, _} =
             insert_draft(scope, %{duration_minutes: 1, recording_byte_size: 5_000_000_000})
  end

  test "concurrent open Conversation Draft inserts for one Student give exactly one success" do
    results =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        scope = insert_scope()

        try do
          parent = self()

          tasks =
            for _ <- 1..2 do
              Task.async(fn ->
                Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                  send(parent, {:ready, self()})
                  receive do: (:go -> insert_draft(scope, %{}))
                end)
              end)
            end

          task_pids =
            for _ <- tasks do
              assert_receive {:ready, task_pid}
              task_pid
            end

          Enum.each(task_pids, &send(&1, :go))
          Enum.map(tasks, &Task.await/1)
        after
          delete_scope(scope)
        end
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    assert Enum.count(results, fn
             {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} -> true
             _ -> false
           end) == 1
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Conversations', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Conversations', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      other_student_user_id: other_student_user_id,
      product_id: product_id,
      program_id: program_id,
      student_id: student_id,
      student_user_id: student_user_id
    }
  end

  defp delete_scope(scope) do
    student_ids = [scope.student_id, scope.other_student_id]

    Repo.query!("DELETE FROM #{@drafts} WHERE student_id = ANY($1)", [student_ids])
    Repo.query!("DELETE FROM student WHERE id = ANY($1)", [student_ids])

    Repo.query!("DELETE FROM \"user\" WHERE id = ANY($1)", [
      [scope.student_user_id, scope.other_student_user_id, scope.mentor_user_id]
    ])

    Repo.query!("DELETE FROM program WHERE id = $1", [scope.program_id])
    Repo.query!("DELETE FROM product WHERE id = $1", [scope.product_id])
  end

  defp insert_conversation(scope, attrs),
    do: insert_row(@conversations, scope, Map.merge(@conversation, attrs))

  defp insert_attempt(scope, attrs),
    do: insert_row(@conversations, scope, Map.merge(@attempt, attrs))

  defp insert_draft(scope, attrs) do
    insert_row(
      @drafts,
      scope,
      Map.merge(
        %{
          academic_year: "2026-2027",
          created_by_email: "mentor@example.org",
          state: "transcribing",
          call_recording_s3_key: "blended-learning/recordings/1.m4a",
          recording_content_type: "audio/mp4",
          recording_byte_size: 1_048_576
        },
        attrs
      )
    )
  end

  defp open_state_attrs("ready"), do: Map.put(@ready_fields, :state, "ready")
  defp open_state_attrs(state), do: %{state: state}

  defp insert_row(table, scope, attrs) do
    {columns, values} =
      %{student_id: scope.student_id, program_id: scope.program_id}
      |> Map.put(:mentor_user_id, scope.mentor_user_id)
      |> Map.merge(attrs)
      |> Enum.sort()
      |> Enum.unzip()

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
