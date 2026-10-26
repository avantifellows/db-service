defmodule Dbservice.HolisticMentorshipNoteChallengesSchemaTest do
  use Dbservice.DataCase, async: false

  @table "holistic_mentorship_post_session_note_challenges"

  test "defines the Post-Session Note Challenge Category contract" do
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
             ["notes_id", "bigint", "NO", nil],
             ["category_code", "character varying", "NO", 100],
             ["inserted_at", "timestamp without time zone", "NO", nil],
             ["updated_at", "timestamp without time zone", "NO", nil]
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
               "hm_post_session_note_challenges_notes_category_unique",
               "CREATE UNIQUE INDEX hm_post_session_note_challenges_notes_category_unique ON public.#{@table} USING btree (notes_id, category_code)"
             ],
             [
               "#{@table}_pkey",
               "CREATE UNIQUE INDEX #{@table}_pkey ON public.#{@table} USING btree (id)"
             ]
           ]
  end

  test "stores one row per selected Challenge Category for each Notes" do
    scope = insert_scope()
    other_scope = insert_scope()
    notes_id = insert_notes(scope)
    other_notes_id = insert_notes(other_scope)

    assert {:ok, _} = insert_challenge(notes_id, "academic.backlogs_workload")
    assert {:ok, _} = insert_challenge(notes_id, "non_academic.financial")
    assert {:ok, _} = insert_challenge(other_notes_id, "academic.backlogs_workload")

    assert Repo.query!(
             "SELECT category_code FROM #{@table} WHERE notes_id = $1 ORDER BY category_code",
             [notes_id]
           ).rows == [["academic.backlogs_workload"], ["non_academic.financial"]]

    assert_constraint(:unique_violation, fn ->
      insert_challenge(notes_id, "academic.backlogs_workload")
    end)

    assert_constraint(:foreign_key_violation, fn ->
      Repo.query("DELETE FROM holistic_mentorship_post_session_notes WHERE id = $1", [notes_id])
    end)
  end

  test "requires a nonblank code without restricting the code list" do
    notes_id = insert_scope() |> insert_notes()

    for blank <- ["", "   ", "\t\n"] do
      assert_constraint(:check_violation, fn -> insert_challenge(notes_id, blank) end)
    end

    # LMS owns and validates the code list; the database accepts any nonblank code.
    assert {:ok, _} = insert_challenge(notes_id, "future_group.new_category")
  end

  test "blocks Challenge Category writes after privacy deletion but allows erasure" do
    scope = insert_scope()
    other_scope = insert_scope()
    notes_id = insert_notes(scope)
    other_notes_id = insert_notes(other_scope)
    {:ok, %{rows: [[challenge_id]]}} = insert_challenge(notes_id, "academic.subject_concept")

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
      insert_challenge(notes_id, "non_academic.financial")
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@table} SET category_code = 'academic.other' WHERE id = $1", [
        challenge_id
      ])
    end)

    # Other Students are unaffected, and erasure deletes rows as it does for answers.
    assert {:ok, %{rows: [[other_challenge_id]]}} =
             insert_challenge(other_notes_id, "non_academic.financial")

    # The guard resolves the Student from NEW, so moving a row onto erased Notes fails.
    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@table} SET notes_id = $1 WHERE id = $2", [
        notes_id,
        other_challenge_id
      ])
    end)

    assert Repo.query!("DELETE FROM #{@table} WHERE notes_id = $1", [notes_id]).num_rows == 1
  end

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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM Challenges', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM Challenges', $1, now(), now()) RETURNING id",
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
            VALUES ($1, $2, 'HM Challenges Phase', 1, 'open', 'Guidance', 1)
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

  defp insert_notes(scope) do
    [[notes_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_post_session_notes
          (student_id, phase_id, author_user_id, state, revision,
           first_drafted_at, last_edited_at)
        VALUES ($1, $2, $3, 'draft', 1, '2026-10-22 10:00:00', '2026-10-22 11:00:00')
        RETURNING id
        """,
        [scope.student_id, scope.phase_id, scope.author_user_id]
      ).rows

    notes_id
  end

  defp insert_challenge(notes_id, category_code) do
    Repo.query(
      "INSERT INTO #{@table} (notes_id, category_code) VALUES ($1, $2) RETURNING id",
      [notes_id, category_code]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
