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
    model_id: "gemini-2.5-pro"
  }

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
    {:ok, _} = insert_conversation(scope, %{source_draft_id: draft_id})

    Repo.query!("UPDATE #{@drafts} SET state = 'saved' WHERE id = $1", [draft_id])
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
          %{model_id: nil}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_draft(scope, open_state_attrs("ready") |> Map.merge(missing))
      end)
    end

    assert {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, open_state_attrs("ready"))

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@drafts} SET model_id = NULL WHERE id = $1", [draft_id])
    end)
  end

  test "requires a time for discarded drafts and only known states" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn -> insert_draft(scope, %{state: "discarded"}) end)
    assert_constraint(:check_violation, fn -> insert_draft(scope, %{state: "archived"}) end)

    assert {:ok, %{rows: [[draft_id]]}} = insert_draft(scope, %{})

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@drafts} SET state = 'discarded' WHERE id = $1", [draft_id])
    end)

    assert {:ok, _} =
             insert_draft(scope, %{state: "discarded", discarded_at: ~N[2026-10-20 11:00:00]})
  end

  test "requires drafted lists to be JSON arrays" do
    scope = insert_scope()

    for column <- [:draft_action_items, :draft_notes],
        value <- [%{"text" => "Revise optics"}, "Revise optics", 3] do
      assert_constraint(:check_violation, fn -> insert_draft(scope, %{column => value}) end)
    end

    assert {:ok, %{rows: [[draft_id]]}} =
             insert_draft(scope, %{
               draft_action_items: [%{"text" => "Revise optics", "owner" => "student"}],
               draft_notes: [%{"heading" => "Studies", "points" => ["Physics is weak"]}]
             })

    assert Repo.query!(
             "SELECT draft_action_items, draft_notes FROM #{@drafts} WHERE id = $1",
             [draft_id]
           ).rows == [
             [
               [%{"owner" => "student", "text" => "Revise optics"}],
               [%{"heading" => "Studies", "points" => ["Physics is weak"]}]
             ]
           ]
  end

  test "requires an audio Call Recording and valid session details" do
    scope = insert_scope()

    for field <- [
          %{recording_content_type: "video/mp4"},
          %{recording_content_type: "application/octet-stream"},
          %{recording_content_type: " audio/mp4"},
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
               occurred_on: ~D[2026-10-20],
               mode: "in_person",
               spoke_with: "both",
               duration_minutes: 240
             })

    Repo.query!(
      "UPDATE #{@drafts} SET state = 'discarded', discarded_at = now() WHERE id = $1",
      [draft_id]
    )

    assert {:ok, _} = insert_draft(scope, %{duration_minutes: 1})
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
          recording_content_type: "audio/mp4"
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
end
