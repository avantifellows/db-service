defmodule Dbservice.AiTestInsightsSchemaTest do
  use Dbservice.DataCase, async: false

  @requests "ai_test_insight_requests"
  @sessions "ai_test_insight_sessions"
  @started ~N[2026-11-26 10:00:00]
  @finished ~N[2026-11-26 10:05:00]
  @submitted %{
    state: "submitted",
    session_date: ~D[2026-11-25],
    submitted_at: ~N[2026-11-26 10:05:00],
    areas_of_concern: "Weak in optics",
    immediate_actions: "Revise ray diagrams"
  }

  # Expected shapes are literals from the af_lms #549 PRD (db-service #880) and its
  # slice issues, never read from the migration.
  test "Insight Requests have the PRD's columns, types, nullability and defaults" do
    ts = "timestamp without time zone"

    assert Repo.query!(
             """
             SELECT column_name::text, data_type::text, datetime_precision,
                    is_nullable::text, column_default::text
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = $1
             ORDER BY ordinal_position
             """,
             [@requests]
           ).rows == [
             ["id", "bigint", nil, "NO", "nextval('ai_test_insight_requests_id_seq'::regclass)"],
             ["request_key", "text", nil, "NO", nil],
             ["student_id", "bigint", nil, "NO", nil],
             ["school_id", "bigint", nil, "NO", nil],
             ["program_id", "bigint", nil, "NO", nil],
             ["academic_year", "text", nil, "NO", nil],
             ["requested_by_user_id", "bigint", nil, "NO", nil],
             ["selected_test_ids", "jsonb", nil, "NO", nil],
             ["notes_snapshot", "jsonb", nil, "NO", "'[]'::jsonb"],
             ["state", "text", nil, "NO", "'queued'::text"],
             ["outcome_code", "text", nil, "YES", nil],
             ["inference_item_id", "bigint", nil, "YES", nil],
             ["requested_at", ts, 0, "NO", "now()"],
             ["started_at", ts, 0, "YES", nil],
             ["finished_at", ts, 0, "YES", nil],
             ["inserted_at", ts, 0, "NO", "now()"],
             ["updated_at", ts, 0, "NO", "now()"]
           ]
  end

  test "Insight Requests reference Student, School, Program, User and Item with NO ACTION" do
    assert Repo.query!(
             """
             SELECT constraint_record.conname::text, attribute.attname::text,
                    referenced.relname::text, constraint_record.confdeltype::text
             FROM pg_constraint AS constraint_record
             JOIN pg_class AS relation ON relation.oid = constraint_record.conrelid
             JOIN pg_class AS referenced ON referenced.oid = constraint_record.confrelid
             JOIN pg_attribute AS attribute
               ON attribute.attrelid = relation.oid
              AND attribute.attnum = constraint_record.conkey[1]
             WHERE relation.relname = $1 AND constraint_record.contype = 'f'
             ORDER BY constraint_record.conname
             """,
             [@requests]
           ).rows == [
             [
               "ai_test_insight_requests_inference_item_id_fkey",
               "inference_item_id",
               "acad_mentorship_inference_items",
               "a"
             ],
             ["ai_test_insight_requests_program_id_fkey", "program_id", "program", "a"],
             [
               "ai_test_insight_requests_requested_by_user_id_fkey",
               "requested_by_user_id",
               "user",
               "a"
             ],
             ["ai_test_insight_requests_school_id_fkey", "school_id", "school", "a"],
             ["ai_test_insight_requests_student_id_fkey", "student_id", "student", "a"]
           ]
  end

  test "Insight Requests have the PRD's five indexes, including the partial predicates" do
    on = "ON public.ai_test_insight_requests USING btree"

    assert Repo.query!(
             """
             SELECT indexname::text, indexdef
             FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = $1
             ORDER BY indexname
             """,
             [@requests]
           ).rows == [
             [
               "ai_test_insight_requests_pkey",
               "CREATE UNIQUE INDEX ai_test_insight_requests_pkey #{on} (id)"
             ],
             [
               "ati_requests_active_student_unique",
               "CREATE UNIQUE INDEX ati_requests_active_student_unique #{on} (student_id) " <>
                 "WHERE (state = ANY (ARRAY['queued'::text, 'running'::text]))"
             ],
             [
               "ati_requests_id_student_unique",
               "CREATE UNIQUE INDEX ati_requests_id_student_unique #{on} (id, student_id)"
             ],
             [
               "ati_requests_inference_item_unique",
               "CREATE UNIQUE INDEX ati_requests_inference_item_unique #{on} (inference_item_id) " <>
                 "WHERE (inference_item_id IS NOT NULL)"
             ],
             [
               "ati_requests_key_unique",
               "CREATE UNIQUE INDEX ati_requests_key_unique #{on} (request_key)"
             ],
             [
               "ati_requests_student_requested_idx",
               "CREATE INDEX ati_requests_student_requested_idx #{on} (student_id, requested_at)"
             ]
           ]
  end

  test "Insight Requests have exactly the six named CHECK constraints" do
    assert Repo.query!("""
           SELECT conname::text
           FROM pg_constraint
           WHERE conrelid = 'public.ai_test_insight_requests'::regclass AND contype = 'c'
           ORDER BY conname
           """).rows == [
             ["ati_requests_academic_year_check"],
             ["ati_requests_lifecycle_check"],
             ["ati_requests_notes_snapshot_check"],
             ["ati_requests_outcome_code_check"],
             ["ati_requests_request_key_check"],
             ["ati_requests_selected_test_ids_check"]
           ]
  end

  describe "one queued or running Insight Request per Student" do
    for {state, finish} <- [
          completed: :item,
          no_data: %{outcome_code: "no_tests_found"},
          failed: %{outcome_code: "timed_out"}
        ] do
      test "a second request waits until the first is #{state}" do
        scope = insert_scope()
        first_id = scope |> insert_request() |> inserted_id()

        assert_constraint(:unique_violation, "ati_requests_active_student_unique", fn ->
          insert_request(scope)
        end)

        assert {:ok, %{num_rows: 1}} =
                 update_request(first_id, %{state: "running", started_at: @started})

        assert_constraint(:unique_violation, "ati_requests_active_student_unique", fn ->
          insert_request(scope)
        end)

        assert {:ok, _} = insert_request(scope, %{student_id: scope.other_student_id})

        finish =
          case unquote(Macro.escape(finish)) do
            :item -> %{inference_item_id: insert_item!(scope.student_id)}
            outcome -> outcome
          end

        assert {:ok, %{num_rows: 1}} =
                 update_request(
                   first_id,
                   Map.merge(%{state: unquote(to_string(state)), finished_at: @finished}, finish)
                 )

        assert {:ok, _} = insert_request(scope)

        assert Repo.query!(
                 "SELECT state FROM #{@requests} WHERE student_id = $1 ORDER BY id",
                 [scope.student_id]
               ).rows == [[unquote(to_string(state))], ["queued"]]
      end
    end
  end

  describe "each state requires its own fields" do
    test "accepts each state with the fields it needs" do
      scope = insert_scope()

      accepted = [
        {"queued bare", %{state: "queued"}},
        {"running without an Item", %{state: "running", started_at: @started}},
        {"running with an Item",
         %{state: "running", started_at: @started, inference_item_id: :item}},
        {"completed",
         %{
           state: "completed",
           started_at: @started,
           finished_at: @finished,
           inference_item_id: :item
         }},
        {"no_data", %{state: "no_data", finished_at: @finished, outcome_code: "no_tests_found"}},
        {"no_data after a start with an Item",
         %{
           state: "no_data",
           started_at: @started,
           finished_at: @finished,
           inference_item_id: :item,
           outcome_code: "no_tests_found"
         }},
        {"failed", %{state: "failed", finished_at: @finished, outcome_code: "timed_out"}}
      ]

      for {label, attrs} <- accepted do
        student_id = insert_student!()

        attrs =
          if attrs[:inference_item_id] == :item,
            do: %{attrs | inference_item_id: insert_item!(student_id)},
            else: attrs

        assert {:ok, _} = insert_request(scope, Map.put(attrs, :student_id, student_id)), label
      end

      assert Repo.query!("SELECT state FROM #{@requests} ORDER BY id").rows ==
               [
                 ["queued"],
                 ["running"],
                 ["running"],
                 ["completed"],
                 ["no_data"],
                 ["no_data"],
                 ["failed"]
               ]
    end

    test "rejects a state whose fields disagree with it" do
      scope = insert_scope()
      item = :item

      rejected = [
        %{state: "queued", started_at: @started},
        %{state: "queued", finished_at: @finished},
        %{state: "queued", inference_item_id: item},
        %{state: "queued", outcome_code: "timed_out"},
        %{state: "running"},
        %{state: "running", inference_item_id: item},
        %{state: "running", started_at: @started, finished_at: @finished},
        %{state: "running", started_at: @started, outcome_code: "timed_out"},
        %{state: "completed", finished_at: @finished, inference_item_id: item},
        %{state: "completed", started_at: @started, inference_item_id: item},
        %{state: "completed", started_at: @started, finished_at: @finished},
        %{
          state: "completed",
          started_at: @started,
          finished_at: @finished,
          inference_item_id: item,
          outcome_code: "timed_out"
        },
        %{state: "no_data", finished_at: @finished},
        %{state: "no_data", outcome_code: "no_tests_found"},
        %{state: "failed", finished_at: @finished},
        %{state: "failed", outcome_code: "timed_out"},
        %{state: "cancelled", finished_at: @finished, outcome_code: "timed_out"},
        %{state: "Queued"}
      ]

      for attrs <- rejected do
        attrs =
          if attrs[:inference_item_id] == :item,
            do: %{attrs | inference_item_id: insert_item!(scope.student_id)},
            else: attrs

        assert_constraint(:check_violation, "ati_requests_lifecycle_check", fn ->
          insert_request(scope, attrs)
        end)
      end

      assert Repo.query!("SELECT count(*) FROM #{@requests}").rows == [[0]]
    end

    test "a queued request can go straight to failed with no Item and no start time" do
      scope = insert_scope()
      id = scope |> insert_request() |> inserted_id()

      assert {:ok, %{num_rows: 1}} =
               update_request(id, %{
                 state: "failed",
                 finished_at: @finished,
                 outcome_code: "timed_out"
               })

      assert Repo.query!(
               "SELECT state, started_at, inference_item_id, outcome_code FROM #{@requests}"
             ).rows == [["failed", nil, nil, "timed_out"]]
    end
  end

  test "ticked tests are a non-empty array of non-empty strings, kept in order" do
    scope = insert_scope()

    for selected_test_ids <- [
          [],
          %{"test" => "test-1"},
          "test-1",
          ["test-2", 1],
          ["test-2", ""],
          [nil]
        ] do
      assert_constraint(:check_violation, "ati_requests_selected_test_ids_check", fn ->
        insert_request(scope, %{selected_test_ids: selected_test_ids})
      end)
    end

    assert {:ok, _} = insert_request(scope, %{selected_test_ids: ["test-9", "test-3", "test-5"]})

    assert Repo.query!("SELECT selected_test_ids FROM #{@requests}").rows == [
             [["test-9", "test-3", "test-5"]]
           ]
  end

  test "the notes copy defaults to an empty array and must be an array" do
    scope = insert_scope()

    for notes_snapshot <- [%{"session_date" => "2026-11-20"}, "notes", 5] do
      assert_constraint(:check_violation, "ati_requests_notes_snapshot_check", fn ->
        insert_request(scope, %{notes_snapshot: notes_snapshot})
      end)
    end

    assert {:ok, _} = insert_request(scope)

    assert Repo.query!("SELECT notes_snapshot FROM #{@requests}").rows == [[[]]]
  end

  test "an outcome code is snake_case, starts with a letter and is at most 64 characters" do
    scope = insert_scope()
    failed = %{state: "failed", finished_at: @finished}

    for outcome_code <- [
          "Timed_out",
          "1_timed_out",
          "timed-out",
          "",
          "t" <> String.duplicate("x", 64)
        ] do
      assert_constraint(:check_violation, "ati_requests_outcome_code_check", fn ->
        insert_request(scope, Map.put(failed, :outcome_code, outcome_code))
      end)
    end

    for outcome_code <- ["timed_out", "t", "t" <> String.duplicate("x", 63), "no_tests_2026"] do
      assert {:ok, _} = insert_request(scope, Map.put(failed, :outcome_code, outcome_code))
    end

    assert Repo.query!("SELECT char_length(outcome_code) FROM #{@requests} ORDER BY id").rows ==
             [[9], [1], [64], [13]]
  end

  test "a request key is unique and 1 to 64 letters, digits, underscores or hyphens" do
    scope = insert_scope()
    failed = %{state: "failed", finished_at: @finished, outcome_code: "timed_out"}

    for request_key <- ["", String.duplicate("k", 65), "request key", "request.key"] do
      assert_constraint(:check_violation, "ati_requests_request_key_check", fn ->
        insert_request(scope, Map.put(failed, :request_key, request_key))
      end)
    end

    accepted = [
      "6f1c2a3e-9b4d-4c8e-a1f2-3b4c5d6e7f80",
      "k",
      String.duplicate("k", 64),
      "Request_Key-01"
    ]

    for request_key <- accepted do
      assert {:ok, _} = insert_request(scope, Map.put(failed, :request_key, request_key))
    end

    assert_constraint(:unique_violation, "ati_requests_key_unique", fn ->
      insert_request(scope, Map.put(failed, :request_key, "Request_Key-01"))
    end)

    assert Repo.query!("SELECT request_key FROM #{@requests} ORDER BY id").rows ==
             Enum.map(accepted, &[&1])
  end

  test "an academic year is YYYY-YYYY with consecutive years" do
    scope = insert_scope()
    failed = %{state: "failed", finished_at: @finished, outcome_code: "timed_out"}

    for academic_year <- [
          "2026-2028",
          "2026-27",
          "2026-2026",
          "2027-2026",
          "2026/2027",
          "26-2027",
          ""
        ] do
      assert_constraint(:check_violation, "ati_requests_academic_year_check", fn ->
        insert_request(scope, Map.put(failed, :academic_year, academic_year))
      end)
    end

    for academic_year <- ["2026-2027", "1999-2000"] do
      assert {:ok, _} = insert_request(scope, Map.put(failed, :academic_year, academic_year))
    end

    assert Repo.query!("SELECT academic_year FROM #{@requests} ORDER BY id").rows ==
             [["2026-2027"], ["1999-2000"]]
  end

  test "a request links to one existing Item, which then cannot be deleted" do
    scope = insert_scope()
    item_id = insert_item!(scope.student_id)
    running = %{state: "running", started_at: @started}

    assert_constraint(
      :foreign_key_violation,
      "ai_test_insight_requests_inference_item_id_fkey",
      fn -> insert_request(scope, Map.put(running, :inference_item_id, item_id + 1_000_000)) end
    )

    assert {:ok, _} = insert_request(scope, Map.put(running, :inference_item_id, item_id))

    assert_constraint(:unique_violation, "ati_requests_inference_item_unique", fn ->
      insert_request(scope, %{
        student_id: scope.other_student_id,
        state: "running",
        started_at: @started,
        inference_item_id: item_id
      })
    end)

    assert_constraint(
      :foreign_key_violation,
      "ai_test_insight_requests_inference_item_id_fkey",
      fn -> Repo.query("DELETE FROM acad_mentorship_inference_items WHERE id = $1", [item_id]) end
    )

    assert Repo.query!("SELECT inference_item_id FROM #{@requests}").rows == [[item_id]]

    assert Repo.query!("SELECT count(*) FROM acad_mentorship_inference_items WHERE id = $1", [
             item_id
           ]).rows == [[1]]
  end

  test "Insight Sessions have the PRD's columns, types, nullability and defaults" do
    ts = "timestamp without time zone"

    assert Repo.query!(
             """
             SELECT column_name::text, data_type::text, datetime_precision,
                    is_nullable::text, column_default::text
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = $1
             ORDER BY ordinal_position
             """,
             [@sessions]
           ).rows == [
             ["id", "bigint", nil, "NO", "nextval('ai_test_insight_sessions_id_seq'::regclass)"],
             ["student_id", "bigint", nil, "NO", nil],
             ["school_id", "bigint", nil, "NO", nil],
             ["program_id", "bigint", nil, "NO", nil],
             ["academic_year", "text", nil, "NO", nil],
             ["author_user_id", "bigint", nil, "NO", nil],
             ["state", "text", nil, "NO", "'draft'::text"],
             ["session_date", "date", 0, "YES", nil],
             ["areas_of_concern", "text", nil, "YES", nil],
             ["immediate_actions", "text", nil, "YES", nil],
             ["other_notes", "text", nil, "YES", nil],
             ["insight_request_id", "bigint", nil, "YES", nil],
             ["revision", "integer", nil, "NO", "1"],
             ["submitted_at", ts, 0, "YES", nil],
             ["inserted_at", ts, 0, "NO", "now()"],
             ["updated_at", ts, 0, "NO", "now()"]
           ]
  end

  test "Insight Sessions reference Student, School, Program, author and own-Student request" do
    assert Repo.query!("""
           SELECT constraint_record.conname::text,
                  array(
                    SELECT attribute.attname::text
                    FROM unnest(constraint_record.conkey) WITH ORDINALITY AS key(attnum, position)
                    JOIN pg_attribute AS attribute
                      ON attribute.attrelid = constraint_record.conrelid
                     AND attribute.attnum = key.attnum
                    ORDER BY key.position
                  ),
                  referenced.relname::text,
                  array(
                    SELECT attribute.attname::text
                    FROM unnest(constraint_record.confkey) WITH ORDINALITY AS key(attnum, position)
                    JOIN pg_attribute AS attribute
                      ON attribute.attrelid = constraint_record.confrelid
                     AND attribute.attnum = key.attnum
                    ORDER BY key.position
                  ),
                  constraint_record.confdeltype::text,
                  constraint_record.confmatchtype::text
           FROM pg_constraint AS constraint_record
           JOIN pg_class AS referenced ON referenced.oid = constraint_record.confrelid
           WHERE constraint_record.conrelid = 'public.ai_test_insight_sessions'::regclass
             AND constraint_record.contype = 'f'
           ORDER BY constraint_record.conname
           """).rows == [
             [
               "ai_test_insight_sessions_author_user_id_fkey",
               ["author_user_id"],
               "user",
               ["id"],
               "a",
               "s"
             ],
             [
               "ai_test_insight_sessions_insight_request_id_fkey",
               ["insight_request_id", "student_id"],
               "ai_test_insight_requests",
               ["id", "student_id"],
               "a",
               "s"
             ],
             [
               "ai_test_insight_sessions_program_id_fkey",
               ["program_id"],
               "program",
               ["id"],
               "a",
               "s"
             ],
             [
               "ai_test_insight_sessions_school_id_fkey",
               ["school_id"],
               "school",
               ["id"],
               "a",
               "s"
             ],
             [
               "ai_test_insight_sessions_student_id_fkey",
               ["student_id"],
               "student",
               ["id"],
               "a",
               "s"
             ]
           ]
  end

  test "Insight Sessions have the PRD's three indexes, including the draft predicate" do
    on = "ON public.ai_test_insight_sessions USING btree"

    assert Repo.query!(
             """
             SELECT indexname::text, indexdef
             FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = $1
             ORDER BY indexname
             """,
             [@sessions]
           ).rows == [
             [
               "ai_test_insight_sessions_pkey",
               "CREATE UNIQUE INDEX ai_test_insight_sessions_pkey #{on} (id)"
             ],
             [
               "ati_sessions_author_student_draft_unique",
               "CREATE UNIQUE INDEX ati_sessions_author_student_draft_unique #{on} " <>
                 "(author_user_id, student_id) WHERE (state = 'draft'::text)"
             ],
             [
               "ati_sessions_insight_request_idx",
               "CREATE INDEX ati_sessions_insight_request_idx #{on} (insight_request_id)"
             ],
             [
               "ati_sessions_student_state_date_idx",
               "CREATE INDEX ati_sessions_student_state_date_idx #{on} " <>
                 "(student_id, state, session_date)"
             ]
           ]
  end

  test "Insight Sessions have exactly the three named CHECK constraints" do
    assert Repo.query!("""
           SELECT conname::text
           FROM pg_constraint
           WHERE conrelid = 'public.ai_test_insight_sessions'::regclass AND contype = 'c'
           ORDER BY conname
           """).rows == [
             ["ati_sessions_academic_year_check"],
             ["ati_sessions_lifecycle_check"],
             ["ati_sessions_revision_check"]
           ]
  end

  describe "one draft per author per Student" do
    test "a second draft by the same author for the same Student is rejected" do
      scope = insert_scope()
      assert {:ok, _} = insert_session(scope, %{areas_of_concern: "Weak in optics"})

      assert_constraint(:unique_violation, "ati_sessions_author_student_draft_unique", fn ->
        insert_session(scope)
      end)

      assert Repo.query!("SELECT areas_of_concern FROM #{@sessions}").rows == [
               ["Weak in optics"]
             ]
    end

    test "another author, another Student, or a submitted first draft leaves room for a draft" do
      scope = insert_scope()
      first_id = scope |> insert_session() |> inserted_id()
      other_author_id = insert_user!()

      assert {:ok, _} = insert_session(scope, %{author_user_id: other_author_id})
      assert {:ok, _} = insert_session(scope, %{student_id: scope.other_student_id})

      assert {:ok, %{num_rows: 1}} = update_session(first_id, @submitted)
      assert {:ok, _} = insert_session(scope)

      assert Repo.query!(
               """
               SELECT author_user_id = $1, student_id = $2, state
               FROM #{@sessions} ORDER BY id
               """,
               [scope.teacher_user_id, scope.student_id]
             ).rows == [
               [true, true, "submitted"],
               [false, true, "draft"],
               [true, false, "draft"],
               [true, true, "draft"]
             ]
    end

    test "an empty draft is accepted with the PRD's defaults" do
      scope = insert_scope()
      assert {:ok, _} = insert_session(scope)

      assert Repo.query!("""
             SELECT state, revision, session_date, areas_of_concern, immediate_actions,
                    other_notes, insight_request_id, submitted_at
             FROM #{@sessions}
             """).rows == [["draft", 1, nil, nil, nil, nil, nil, nil]]
    end
  end

  describe "a submitted session needs a date, a submit time and both required notes" do
    for field <- [:areas_of_concern, :immediate_actions],
        {label, value} <- [
          {"null", nil},
          {"empty", ""},
          {"spaces", "   "},
          {"a tab", "\t"},
          {"a newline", "\n"},
          {"mixed whitespace", " \t\n "}
        ] do
      test "#{field} that is #{label} is rejected on insert and on submit" do
        scope = insert_scope()
        attrs = Map.put(@submitted, unquote(field), unquote(value))

        assert_constraint(:check_violation, "ati_sessions_lifecycle_check", fn ->
          insert_session(scope, attrs)
        end)

        draft_id = scope |> insert_session() |> inserted_id()

        assert_constraint(:check_violation, "ati_sessions_lifecycle_check", fn ->
          update_session(draft_id, attrs)
        end)

        assert Repo.query!("SELECT state FROM #{@sessions}").rows == [["draft"]]
      end
    end

    for field <- [:session_date, :submitted_at] do
      test "a missing #{field} is rejected on insert and on submit" do
        scope = insert_scope()
        attrs = Map.put(@submitted, unquote(field), nil)

        assert_constraint(:check_violation, "ati_sessions_lifecycle_check", fn ->
          insert_session(scope, attrs)
        end)

        draft_id = scope |> insert_session() |> inserted_id()

        assert_constraint(:check_violation, "ati_sessions_lifecycle_check", fn ->
          update_session(draft_id, attrs)
        end)

        assert Repo.query!("SELECT state FROM #{@sessions}").rows == [["draft"]]
      end
    end

    test "Other notes is optional, on insert and on submit" do
      scope = insert_scope()
      attrs = Map.put(@submitted, :other_notes, nil)

      assert {:ok, _} = insert_session(scope, attrs)
      draft_id = scope |> insert_session(%{author_user_id: insert_user!()}) |> inserted_id()
      assert {:ok, %{num_rows: 1}} = update_session(draft_id, attrs)

      assert Repo.query!("""
             SELECT state, session_date, submitted_at, areas_of_concern,
                    immediate_actions, other_notes
             FROM #{@sessions} ORDER BY id
             """).rows ==
               List.duplicate(
                 [
                   "submitted",
                   ~D[2026-11-25],
                   ~N[2026-11-26 10:05:00],
                   "Weak in optics",
                   "Revise ray diagrams",
                   nil
                 ],
                 2
               )
    end

    test "a draft with a submit time and an unknown state are rejected" do
      scope = insert_scope()

      for attrs <- [
            %{submitted_at: @finished},
            Map.put(@submitted, :state, "archived"),
            Map.put(@submitted, :state, "Submitted"),
            %{state: "Draft"}
          ] do
        assert_constraint(:check_violation, "ati_sessions_lifecycle_check", fn ->
          insert_session(scope, attrs)
        end)
      end

      assert Repo.query!("SELECT count(*) FROM #{@sessions}").rows == [[0]]
    end
  end

  test "an Insight Session's academic year is YYYY-YYYY with consecutive years" do
    scope = insert_scope()

    for academic_year <- ["2026-2028", "2026-27", "2027-2026", ""] do
      assert_constraint(:check_violation, "ati_sessions_academic_year_check", fn ->
        insert_session(scope, %{academic_year: academic_year})
      end)
    end

    assert {:ok, _} = insert_session(scope, %{academic_year: "2025-2026"})
    assert Repo.query!("SELECT academic_year FROM #{@sessions}").rows == [["2025-2026"]]
  end

  describe "revision" do
    test "starts above zero" do
      scope = insert_scope()

      for revision <- [0, -1] do
        assert_constraint(:check_violation, "ati_sessions_revision_check", fn ->
          insert_session(scope, %{revision: revision})
        end)
      end

      assert Repo.query!("SELECT count(*) FROM #{@sessions}").rows == [[0]]
    end

    test "a save with a stale revision changes no row; the current one moves it on by one" do
      scope = insert_scope()
      id = scope |> insert_session(%{areas_of_concern: "first"}) |> inserted_id()

      save = fn revision, text ->
        Repo.query(
          """
          UPDATE #{@sessions}
          SET areas_of_concern = $3, revision = revision + 1, updated_at = now()
          WHERE id = $1 AND revision = $2
          """,
          [id, revision, text]
        )
      end

      assert {:ok, %{num_rows: 1}} = save.(1, "second")
      assert {:ok, %{num_rows: 0}} = save.(1, "stale tab")

      assert Repo.query!("SELECT areas_of_concern, revision FROM #{@sessions}").rows == [
               ["second", 2]
             ]
    end
  end

  describe "the linked Insight Request" do
    test "must belong to the session's Student, or be null" do
      scope = insert_scope()
      own_request_id = scope |> insert_request() |> inserted_id()

      other_request_id =
        scope |> insert_request(%{student_id: scope.other_student_id}) |> inserted_id()

      assert_constraint(
        :foreign_key_violation,
        "ai_test_insight_sessions_insight_request_id_fkey",
        fn -> insert_session(scope, %{insight_request_id: other_request_id}) end
      )

      assert_constraint(
        :foreign_key_violation,
        "ai_test_insight_sessions_insight_request_id_fkey",
        fn -> insert_session(scope, %{insight_request_id: own_request_id + 1_000_000}) end
      )

      assert {:ok, _} = insert_session(scope, %{insight_request_id: own_request_id})

      assert {:ok, _} =
               insert_session(scope, %{author_user_id: insert_user!(), insight_request_id: nil})

      assert Repo.query!("SELECT insight_request_id FROM #{@sessions} ORDER BY id").rows == [
               [own_request_id],
               [nil]
             ]
    end

    test "a linked session cannot move to another Student" do
      scope = insert_scope()
      request_id = scope |> insert_request() |> inserted_id()
      id = scope |> insert_session(%{insight_request_id: request_id}) |> inserted_id()

      assert_constraint(
        :foreign_key_violation,
        "ai_test_insight_sessions_insight_request_id_fkey",
        fn -> update_session(id, %{student_id: scope.other_student_id}) end
      )

      assert Repo.query!("SELECT student_id FROM #{@sessions}").rows == [[scope.student_id]]
    end

    test "a request that a session names cannot be deleted" do
      scope = insert_scope()
      request_id = scope |> insert_request() |> inserted_id()
      assert {:ok, _} = insert_session(scope, %{insight_request_id: request_id})

      assert_constraint(
        :foreign_key_violation,
        "ai_test_insight_sessions_insight_request_id_fkey",
        fn -> Repo.query("DELETE FROM #{@requests} WHERE id = $1", [request_id]) end
      )

      assert Repo.query!("SELECT id FROM #{@requests}").rows == [[request_id]]
    end
  end

  defp insert_user! do
    [[user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    user_id
  end

  defp insert_session(scope, attrs \\ %{}) do
    insert_row(
      @sessions,
      Map.merge(
        %{
          student_id: scope.student_id,
          school_id: scope.school_id,
          program_id: scope.program_id,
          academic_year: "2026-2027",
          author_user_id: scope.teacher_user_id
        },
        attrs
      )
    )
  end

  defp update_session(id, attrs) do
    {columns, values} = attrs |> Enum.sort() |> Enum.unzip()

    assignments =
      columns |> Enum.with_index(2) |> Enum.map_join(", ", fn {c, i} -> "#{c} = $#{i}" end)

    Repo.query("UPDATE #{@sessions} SET #{assignments} WHERE id = $1", [id | values])
  end

  defp insert_scope do
    [[student_user_id], [other_student_user_id], [teacher_user_id]] =
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

    [[school_id]] =
      Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('AI Test Insights', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('AI Test Insights', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      other_student_id: other_student_id,
      program_id: program_id,
      school_id: school_id,
      student_id: student_id,
      teacher_user_id: teacher_user_id
    }
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

  # An AI Mentorship Guide Item for the Student, in its own generator run.
  defp insert_item!(student_id) do
    [[session_id]] =
      Repo.query!("INSERT INTO acad_mentorship_inference_sessions DEFAULT VALUES RETURNING id").rows

    [[item_id]] =
      Repo.query!(
        "INSERT INTO acad_mentorship_inference_items (session_id, student_id) VALUES ($1, $2) RETURNING id",
        [session_id, student_id]
      ).rows

    item_id
  end

  defp insert_request(scope, attrs \\ %{}) do
    insert_row(
      @requests,
      Map.merge(
        %{
          request_key: "request-#{System.unique_integer([:positive])}",
          student_id: scope.student_id,
          school_id: scope.school_id,
          program_id: scope.program_id,
          academic_year: "2026-2027",
          requested_by_user_id: scope.teacher_user_id,
          selected_test_ids: ["test-2", "test-1"]
        },
        attrs
      )
    )
  end

  defp update_request(id, attrs) do
    {columns, values} = attrs |> Enum.sort() |> Enum.unzip()

    assignments =
      columns |> Enum.with_index(2) |> Enum.map_join(", ", fn {c, i} -> "#{c} = $#{i}" end)

    Repo.query("UPDATE #{@requests} SET #{assignments} WHERE id = $1", [id | values])
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

  defp assert_constraint(code, constraint, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code, constraint: ^constraint}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
