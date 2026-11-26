defmodule Dbservice.AiTestInsightsSchemaTest do
  use Dbservice.DataCase, async: false

  @requests "ai_test_insight_requests"
  @started ~N[2026-11-26 10:00:00]
  @finished ~N[2026-11-26 10:05:00]

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
