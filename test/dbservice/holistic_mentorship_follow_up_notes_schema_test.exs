defmodule Dbservice.HolisticMentorshipFollowUpNotesSchemaTest do
  use Dbservice.DataCase, async: false

  @table "holistic_mentorship_follow_up_notes"

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
