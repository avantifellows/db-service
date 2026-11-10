defmodule Dbservice.HolisticMentorshipDictationUsageSchemaTest do
  use Dbservice.DataCase, async: false

  @table "holistic_mentorship_dictation_usage_records"

  test "defines the content-free Dictation Usage Record contract" do
    assert Repo.query!(
             """
             SELECT column_name, data_type, is_nullable, column_default
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = $1
             ORDER BY ordinal_position
             """,
             [@table]
           ).rows == [
             ["id", "bigint", "NO", "nextval('#{@table}_id_seq'::regclass)"],
             ["mentor_user_id", "bigint", "NO", nil],
             ["school_id", "bigint", "NO", nil],
             ["program_id", "bigint", "NO", nil],
             ["note_kind", "character varying", "NO", nil],
             ["audio_seconds", "integer", "NO", nil],
             ["characters_returned", "integer", "NO", "0"],
             ["outcome", "character varying", "NO", nil],
             ["completed_at", "timestamp without time zone", "YES", nil],
             ["inserted_at", "timestamp without time zone", "NO", "now()"],
             ["updated_at", "timestamp without time zone", "NO", "now()"]
           ]

    # Restrictive FKs: 'a' is NO ACTION. There is no Student, Phase or Question link.
    assert Repo.query!(
             """
             SELECT a.attname, ref.relname, f.confdeltype
             FROM pg_constraint f
             JOIN pg_attribute a ON a.attrelid = f.conrelid AND a.attnum = ANY(f.conkey)
             JOIN pg_class ref ON ref.oid = f.confrelid
             WHERE f.conrelid = to_regclass($1) AND f.contype = 'f'
             ORDER BY a.attname
             """,
             [@table]
           ).rows == [
             ["mentor_user_id", "user", "a"],
             ["program_id", "program", "a"],
             ["school_id", "school", "a"]
           ]

    assert Repo.query!(
             """
             SELECT conname FROM pg_constraint
             WHERE conrelid = to_regclass($1) AND contype = 'c'
             ORDER BY conname
             """,
             [@table]
           ).rows == [
             ["hm_dictation_usage_audio_seconds_check"],
             ["hm_dictation_usage_characters_returned_check"],
             ["hm_dictation_usage_note_kind_check"],
             ["hm_dictation_usage_outcome_check"]
           ]

    assert Repo.query!(
             """
             SELECT indexname, indexdef FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = $1
             ORDER BY indexname
             """,
             [@table]
           ).rows == [
             [
               "hm_dictation_usage_mentor_time_idx",
               "CREATE INDEX hm_dictation_usage_mentor_time_idx ON public.#{@table} USING btree (mentor_user_id, inserted_at)"
             ],
             [
               "#{@table}_pkey",
               "CREATE UNIQUE INDEX #{@table}_pkey ON public.#{@table} USING btree (id)"
             ]
           ]

    assert Repo.query!(
             """
             SELECT trigger_name FROM information_schema.triggers
             WHERE event_object_schema = 'public' AND event_object_table = $1
             """,
             [@table]
           ).rows == []
  end

  test "records an attempt as failed first, then updates it to its final outcome" do
    scope = insert_scope()

    assert {:ok, %{rows: [[id, 0, nil]]}} =
             insert_usage(scope, "post_session", 125, "failed")

    assert {:ok, %{rows: [["ok", 420, %NaiveDateTime{}]]}} =
             Repo.query(
               """
               UPDATE #{@table}
               SET outcome = 'ok', characters_returned = 420, completed_at = now()
               WHERE id = $1
               RETURNING outcome, characters_returned, completed_at
               """,
               [id]
             )
  end

  test "stores many attempts per Mentor for both note kinds and every outcome" do
    scope = insert_scope()

    for {kind, outcome} <- [
          {"post_session", "ok"},
          {"post_session", "failed"},
          {"follow_up", "nothing_heard"},
          {"follow_up", "ok"}
        ] do
      assert {:ok, _} = insert_usage(scope, kind, 1, outcome)
    end

    assert Repo.query!(
             "SELECT count(*), sum(audio_seconds) FROM #{@table} WHERE mentor_user_id = $1",
             [scope.mentor_user_id]
           ).rows == [[4, 4]]
  end

  test "rejects an unknown note kind or outcome" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn -> insert_usage(scope, "voice", 10, "ok") end)
    assert_constraint(:check_violation, fn -> insert_usage(scope, "follow_up", 10, "done") end)
  end

  test "bounds audio seconds to one recording and keeps characters non-negative" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn -> insert_usage(scope, "post_session", 0, "ok") end)
    assert_constraint(:check_violation, fn -> insert_usage(scope, "post_session", 126, "ok") end)

    assert_constraint(:check_violation, fn ->
      insert_usage(scope, "post_session", 10, "ok", -1)
    end)
  end

  test "requires an existing Mentor, School and Program" do
    scope = insert_scope()

    for key <- [:mentor_user_id, :school_id, :program_id] do
      assert_constraint(:foreign_key_violation, fn ->
        insert_usage(%{scope | key => -1}, "post_session", 10, "ok")
      end)
    end
  end

  defp insert_usage(scope, kind, seconds, outcome, characters \\ 0) do
    Repo.query(
      """
      INSERT INTO #{@table}
        (mentor_user_id, school_id, program_id, note_kind, audio_seconds,
         characters_returned, outcome)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id, characters_returned, completed_at
      """,
      [
        scope.mentor_user_id,
        scope.school_id,
        scope.program_id,
        kind,
        seconds,
        characters,
        outcome
      ]
    )
  end

  defp insert_scope do
    [[mentor_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[school_id]] =
      Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM Dictation', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM Dictation', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{mentor_user_id: mentor_user_id, school_id: school_id, program_id: program_id}
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
