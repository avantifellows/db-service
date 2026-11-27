defmodule Dbservice.HolisticMentorshipFollowUpNotesSchemaTest do
  use Dbservice.DataCase, async: false

  @table "holistic_mentorship_follow_up_notes"
  @erased "Content erased under approved privacy request"
  @erasures "holistic_mentorship_follow_up_erasures"

  test "defines the immutable Follow-up Note contract" do
    assert Repo.query!(
             """
             SELECT column_name, data_type, is_nullable, character_maximum_length
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = $1
             ORDER BY ordinal_position
             """,
             [@table]
           ).rows == [
             ["id", "bigint", "NO", nil],
             ["student_id", "bigint", "NO", nil],
             ["phase_id", "bigint", "NO", nil],
             ["author_user_id", "bigint", "NO", nil],
             ["author_email", "character varying", "NO", 255],
             ["challenges_answer", "text", "YES", nil],
             ["solutions_answer", "text", "YES", nil],
             ["action_plan_answer", "text", "YES", nil],
             ["submitted_at", "timestamp without time zone", "NO", nil],
             ["inserted_at", "timestamp without time zone", "NO", nil],
             ["updated_at", "timestamp without time zone", "NO", nil]
           ]

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
             ["author_user_id", "user", "a"],
             ["phase_id", "holistic_mentorship_phases", "a"],
             ["student_id", "student", "a"]
           ]

    assert Repo.query!(
             """
             SELECT conname FROM pg_constraint
             WHERE conrelid = to_regclass($1) AND contype = 'c'
             ORDER BY conname
             """,
             [@table]
           ).rows == [
             ["hm_follow_up_notes_answers_check"],
             ["hm_follow_up_notes_any_answer_check"],
             ["hm_follow_up_notes_author_email_check"]
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
               "hm_follow_up_notes_author_idx",
               "CREATE INDEX hm_follow_up_notes_author_idx ON public.#{@table} USING btree (author_user_id)"
             ],
             [
               "hm_follow_up_notes_phase_idx",
               "CREATE INDEX hm_follow_up_notes_phase_idx ON public.#{@table} USING btree (phase_id)"
             ],
             [
               "hm_follow_up_notes_student_phase_time_idx",
               "CREATE INDEX hm_follow_up_notes_student_phase_time_idx ON public.#{@table} USING btree (student_id, phase_id, submitted_at)"
             ],
             [
               "#{@table}_pkey",
               "CREATE UNIQUE INDEX #{@table}_pkey ON public.#{@table} USING btree (id)"
             ]
           ]

    assert Repo.query!(
             """
             SELECT DISTINCT trigger_name FROM information_schema.triggers
             WHERE event_object_schema = 'public' AND event_object_table = $1
             ORDER BY trigger_name
             """,
             [@table]
           ).rows == [
             ["hm_follow_up_notes_immutable"],
             ["hm_follow_up_notes_submitted_notes_check"]
           ]
  end

  test "stores many Follow-up Notes per Student and Phase after submitted Notes" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    assert {:ok, %{rows: [[first_id]]}} =
             insert_follow_up(scope, %{challenges: "Exam stress", solutions: "Study plan"})

    assert {:ok, %{rows: [[second_id]]}} =
             insert_follow_up(scope, %{action_plan: "Partly followed"})

    assert Repo.query!(
             """
             SELECT id, author_email, challenges_answer, solutions_answer, action_plan_answer
             FROM holistic_mentorship_follow_up_notes
             WHERE student_id = $1 AND phase_id = $2
             ORDER BY id
             """,
             [scope.student_id, scope.phase_id]
           ).rows == [
             [first_id, "mentor@example.com", "Exam stress", "Study plan", nil],
             [second_id, "mentor@example.com", nil, nil, "Partly followed"]
           ]
  end

  test "requires submitted Post-Session Notes for the same Student and Phase" do
    missing_scope = insert_scope()

    assert_constraint(:check_violation, fn ->
      insert_follow_up(missing_scope, %{challenges: "No Notes yet"})
    end)

    draft_scope = insert_scope()
    assert {:ok, _} = insert_notes(draft_scope, "draft")

    assert_constraint(:check_violation, fn ->
      insert_follow_up(draft_scope, %{challenges: "Draft Notes only"})
    end)

    submitted_scope = insert_scope()
    assert {:ok, _} = insert_notes(submitted_scope, "submitted")

    assert_constraint(:check_violation, fn ->
      insert_follow_up(%{submitted_scope | phase_id: draft_scope.phase_id}, %{
        challenges: "Other Phase"
      })
    end)

    assert_constraint(:check_violation, fn ->
      insert_follow_up(%{submitted_scope | student_id: draft_scope.student_id}, %{
        challenges: "Other Student"
      })
    end)
  end

  test "requires at least one nonblank bounded answer" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    assert_constraint(:check_violation, fn -> insert_follow_up(scope, %{}) end)

    for key <- [:challenges, :solutions, :action_plan], blank <- ["", "   ", "\t\n"] do
      assert_constraint(:check_violation, fn ->
        insert_follow_up(scope, %{key => blank, other_key(key) => "Answered"})
      end)
    end

    for key <- [:challenges, :solutions, :action_plan] do
      assert_constraint(:check_violation, fn ->
        insert_follow_up(scope, %{key => String.duplicate("a", 10_001)})
      end)

      assert {:ok, _} = insert_follow_up(scope, %{key => String.duplicate("a", 10_000)})
    end
  end

  test "requires a nonblank author email snapshot" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    for author_email <- ["", "   ", "\t\n"] do
      assert_constraint(:check_violation, fn ->
        insert_follow_up(scope, %{challenges: "Answered"}, author_email)
      end)
    end

    assert_constraint(:not_null_violation, fn ->
      insert_follow_up(scope, %{challenges: "Answered"}, nil)
    end)
  end

  test "rejects Follow-up Notes after privacy deletion" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    Repo.query!(
      """
      INSERT INTO holistic_mentorship_privacy_deletions
        (student_id, actor_user_id, reason, profile_summaries_erased,
         post_session_answers_erased, historical_answers_erased, occurred_at)
      VALUES ($1, $2, 'approved-request', 0, 0, 0, now())
      """,
      [scope.student_id, scope.author_user_id]
    )

    assert_constraint(:check_violation, fn ->
      insert_follow_up(scope, %{challenges: "After erasure"})
    end)
  end

  test "keeps Follow-up Notes immutable" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")
    {:ok, %{rows: [[follow_up_id]]}} = insert_follow_up(scope, %{challenges: "Original"})

    assert_constraint(:check_violation, fn ->
      Repo.query(
        "UPDATE holistic_mentorship_follow_up_notes SET challenges_answer = 'Changed' WHERE id = $1",
        [follow_up_id]
      )
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM holistic_mentorship_follow_up_notes WHERE id = $1", [follow_up_id])
    end)

    assert Repo.query!(
             "SELECT challenges_answer FROM holistic_mentorship_follow_up_notes WHERE id = $1",
             [follow_up_id]
           ).rows == [["Original"]]
  end

  test "privacy erasure requires this Student's tombstone and preserves all metadata and nulls" do
    scope = insert_scope()
    other_scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    {:ok, %{rows: [[id]]}} =
      insert_follow_up(scope, %{challenges: "Original", solutions: @erased})

    {:ok, %{rows: [[action_id]]}} = insert_follow_up(scope, %{action_plan: "Original action"})
    before = follow_up_row(id)
    action_before = follow_up_row(action_id)
    assert_constraint(:check_violation, fn -> erase_follow_up(id) end)
    insert_tombstone(other_scope)
    assert_constraint(:check_violation, fn -> erase_follow_up(id) end)
    insert_tombstone(scope)

    assert {:ok, %{num_rows: 1}} = erase_follow_up(id)
    assert follow_up_row(id) == Map.merge(before, %{"challenges_answer" => @erased})
    assert {:ok, %{num_rows: 1}} = erase_follow_up(action_id)

    assert follow_up_row(action_id) ==
             Map.merge(action_before, %{"action_plan_answer" => @erased})

    assert_constraint(:check_violation, fn -> erase_follow_up(id) end)

    assert_constraint(:check_violation, fn ->
      insert_follow_up(scope, %{challenges: "New content"})
    end)
  end

  test "privacy exception rejects partial erasure, metadata changes, restoration and deletion" do
    scope = insert_scope()
    assert {:ok, _} = insert_notes(scope, "submitted")

    {:ok, %{rows: [[id]]}} =
      insert_follow_up(scope, %{challenges: "Original", solutions: "Original solution"})

    before = follow_up_row(id)
    insert_tombstone(scope)

    for assignment <- [
          "challenges_answer = $2",
          "challenges_answer = NULL, solutions_answer = NULL",
          "challenges_answer = 'Edited'",
          "challenges_answer = challenges_answer"
        ] do
      params = if String.contains?(assignment, "$2"), do: [id, @erased], else: [id]

      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@table} SET #{assignment} WHERE id = $1", params)
      end)
    end

    for metadata_change <- [
          "id = id + 1000000",
          "student_id = student_id + 1000000",
          "phase_id = phase_id + 1000000",
          "author_user_id = author_user_id + 1000000",
          "author_email = 'changed@example.com'",
          "submitted_at = submitted_at + interval '1 second'",
          "inserted_at = inserted_at + interval '1 second'",
          "updated_at = updated_at + interval '1 second'"
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query(
          "UPDATE #{@table} SET challenges_answer = $2, solutions_answer = $2, #{metadata_change} WHERE id = $1",
          [id, @erased]
        )
      end)
    end

    assert follow_up_row(id) == before
    assert {:ok, _} = erase_follow_up(id)

    for assignment <- [
          "challenges_answer = 'Restored'",
          "challenges_answer = NULL",
          "action_plan_answer = $2",
          "challenges_answer = challenges_answer"
        ] do
      params = if String.contains?(assignment, "$2"), do: [id, @erased], else: [id]

      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@table} SET #{assignment} WHERE id = $1", params)
      end)
    end

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM #{@table} WHERE id = $1", [id])
    end)
  end

  test "records one immutable positive Follow-up erasure audit without changing the tombstone" do
    scope = insert_scope()
    deletion_id = insert_tombstone(scope)

    tombstone =
      Repo.query!(
        "SELECT to_jsonb(d) FROM holistic_mentorship_privacy_deletions d WHERE id = $1",
        [
          deletion_id
        ]
      ).rows

    assert {:ok, %{rows: [[audit_id]]}} = insert_erasure(deletion_id, scope.author_user_id)

    assert Repo.query!(
             "SELECT privacy_deletion_id, actor_user_id, reason, answers_erased FROM #{@erasures} WHERE id = $1",
             [audit_id]
           ).rows == [[deletion_id, scope.author_user_id, "Approved follow-up erasure", 2]]

    assert_constraint(:unique_violation, fn ->
      insert_erasure(deletion_id, scope.author_user_id)
    end)

    for query <- [
          "UPDATE #{@erasures} SET answers_erased = 3 WHERE id = $1",
          "UPDATE #{@erasures} SET reason = reason WHERE id = $1",
          "DELETE FROM #{@erasures} WHERE id = $1"
        ] do
      assert_constraint(:check_violation, fn -> Repo.query(query, [audit_id]) end)
    end

    assert Repo.query!(
             "SELECT to_jsonb(d) FROM holistic_mentorship_privacy_deletions d WHERE id = $1",
             [deletion_id]
           ).rows == tombstone
  end

  test "Follow-up erasure audit requires valid references, a positive count and nonblank reason" do
    scope = insert_scope()
    deletion_id = insert_tombstone(scope)

    for count <- [0, -1] do
      assert_constraint(:check_violation, fn ->
        insert_erasure(deletion_id, scope.author_user_id, count)
      end)
    end

    for reason <- ["", "  ", "\t\n"] do
      assert_constraint(:check_violation, fn ->
        insert_erasure(deletion_id, scope.author_user_id, 1, reason)
      end)
    end

    assert_constraint(:foreign_key_violation, fn ->
      insert_erasure(-1, scope.author_user_id)
    end)

    assert_constraint(:foreign_key_violation, fn -> insert_erasure(deletion_id, -1) end)

    assert Repo.query!(
             """
             SELECT a.attname, f.confdeltype
             FROM pg_constraint f
             JOIN pg_attribute a ON a.attrelid = f.conrelid AND a.attnum = ANY(f.conkey)
             WHERE f.conrelid = to_regclass($1) AND f.contype = 'f'
             ORDER BY a.attname
             """,
             [@erasures]
           ).rows == [["actor_user_id", "a"], ["privacy_deletion_id", "a"]]
  end

  defp follow_up_row(id) do
    [[row]] = Repo.query!("SELECT to_jsonb(note) FROM #{@table} note WHERE id = $1", [id]).rows
    row
  end

  defp erase_follow_up(id) do
    Repo.query(
      """
      UPDATE #{@table}
      SET challenges_answer = CASE WHEN challenges_answer IS NULL THEN NULL ELSE $2 END,
          solutions_answer = CASE WHEN solutions_answer IS NULL THEN NULL ELSE $2 END,
          action_plan_answer = CASE WHEN action_plan_answer IS NULL THEN NULL ELSE $2 END
      WHERE id = $1
      """,
      [id, @erased]
    )
  end

  defp insert_tombstone(scope) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_privacy_deletions
          (student_id, actor_user_id, reason, profile_summaries_erased,
           post_session_answers_erased, historical_answers_erased, occurred_at)
        VALUES ($1, $2, 'Original privacy request', 0, 0, 0, now()) RETURNING id
        """,
        [scope.student_id, scope.author_user_id]
      ).rows

    id
  end

  defp insert_erasure(deletion_id, actor_id, count \\ 2, reason \\ "Approved follow-up erasure") do
    Repo.query(
      """
      INSERT INTO #{@erasures}
        (privacy_deletion_id, actor_user_id, reason, answers_erased, occurred_at)
      VALUES ($1, $2, $3, $4, now()) RETURNING id
      """,
      [deletion_id, actor_id, reason, count]
    )
  end

  defp other_key(:challenges), do: :solutions
  defp other_key(:solutions), do: :action_plan
  defp other_key(:action_plan), do: :challenges

  defp insert_scope do
    [[student_user_id], [author_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()), (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM Follow-up', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM Follow-up', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[grade_id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES (11, now(), now()) RETURNING id"
      ).rows

    {:ok, phase_id} =
      Repo.transaction(fn ->
        [[plan_id]] =
          Repo.query!(
            "INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year) VALUES ($1, '2026-2027') RETURNING id",
            [program_id]
          ).rows

        [[phase_id]] =
          Repo.query!(
            """
            INSERT INTO holistic_mentorship_phases
              (phase_plan_id, grade_id, title, position, state, guidance_markdown, revision)
            VALUES ($1, $2, 'HM Follow-up Phase', 1, 'open', 'Guidance', 1)
            RETURNING id
            """,
            [plan_id, grade_id]
          ).rows

        Repo.query!(
          "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Reflect', 1)",
          [phase_id]
        )

        phase_id
      end)

    %{author_user_id: author_user_id, phase_id: phase_id, student_id: student_id}
  end

  defp insert_notes(scope, "draft") do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_post_session_notes
        (student_id, phase_id, author_user_id, state, revision,
         first_drafted_at, last_edited_at)
      VALUES ($1, $2, $3, 'draft', 1, '2026-09-30 10:00:00', '2026-09-30 11:00:00')
      """,
      [scope.student_id, scope.phase_id, scope.author_user_id]
    )
  end

  defp insert_notes(scope, "submitted") do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_post_session_notes
        (student_id, phase_id, author_user_id, state, revision,
         first_drafted_at, first_submitted_at, last_edited_at)
      VALUES ($1, $2, $3, 'submitted', 1,
              '2026-09-30 10:00:00', '2026-09-30 11:00:00', '2026-09-30 11:00:00')
      """,
      [scope.student_id, scope.phase_id, scope.author_user_id]
    )
  end

  defp insert_follow_up(scope, answers, author_email \\ "mentor@example.com") do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_follow_up_notes
        (student_id, phase_id, author_user_id, author_email,
         challenges_answer, solutions_answer, action_plan_answer, submitted_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, now())
      RETURNING id
      """,
      [
        scope.student_id,
        scope.phase_id,
        scope.author_user_id,
        author_email,
        Map.get(answers, :challenges),
        Map.get(answers, :solutions),
        Map.get(answers, :action_plan)
      ]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
