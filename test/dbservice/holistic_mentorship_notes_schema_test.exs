defmodule Dbservice.HolisticMentorshipNotesSchemaTest do
  use Dbservice.DataCase, async: false

  test "rejects stale Post-Session Notes revisions" do
    scope = insert_scope()

    [[notes_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_post_session_notes
          (student_id, phase_id, author_user_id, state, revision,
           first_drafted_at, last_edited_at)
        VALUES ($1, $2, $3, 'draft', 1, now(), now())
        RETURNING id
        """,
        [scope.student_id, scope.phase_id, scope.author_user_id]
      ).rows

    assert Repo.query!(
             """
             UPDATE holistic_mentorship_post_session_notes
             SET revision = revision + 1, last_edited_at = now()
             WHERE id = $1 AND revision = $2
             RETURNING revision
             """,
             [notes_id, 1]
           ).rows == [[2]]

    assert Repo.query!(
             """
             UPDATE holistic_mentorship_post_session_notes
             SET revision = revision + 1, last_edited_at = now()
             WHERE id = $1 AND revision = $2
             RETURNING revision
             """,
             [notes_id, 1]
           ).rows == []
  end

  test "enforces one valid Notes lifecycle per Student and Phase" do
    scope = insert_scope()
    assert {:ok, _} = insert_note(scope, "draft", 1, nil)

    assert_constraint(:unique_violation, fn -> insert_note(scope, "draft", 1, nil) end)

    other_scope = insert_scope()

    assert_constraint(:check_violation, fn ->
      insert_note(other_scope, "reviewed", 1, nil)
    end)

    assert_constraint(:check_violation, fn ->
      insert_note(other_scope, "draft", 0, nil)
    end)

    assert_constraint(:check_violation, fn ->
      insert_note(other_scope, "submitted", 1, nil)
    end)

    assert {:ok, _} = insert_note(other_scope, "submitted", 1, ~N[2026-07-16 12:00:00])
  end

  test "stores one current answer per configured Question from the Notes Phase" do
    scope = insert_scope()
    other_scope = insert_scope()
    {:ok, %{rows: [[notes_id]]}} = insert_note(scope, "draft", 1, nil)

    assert {:ok, _} = insert_answer(notes_id, Enum.at(scope.question_ids, 1), "Second")
    assert {:ok, _} = insert_answer(notes_id, Enum.at(scope.question_ids, 0), "First")

    assert Repo.query!(
             """
             SELECT answer.answer
             FROM holistic_mentorship_post_session_answers AS answer
             JOIN holistic_mentorship_phase_questions AS question ON question.id = answer.question_id
             WHERE answer.notes_id = $1
             ORDER BY question.position
             """,
             [notes_id]
           ).rows == [["First"], ["Second"]]

    assert_constraint(:unique_violation, fn ->
      insert_answer(notes_id, Enum.at(scope.question_ids, 0), "Replacement")
    end)

    assert_constraint(:check_violation, fn ->
      insert_answer(notes_id, Enum.at(other_scope.question_ids, 0), "Wrong Phase")
    end)
  end

  test "defines a content-free Post-Session Notes mutation audit" do
    assert column_types("holistic_mentorship_post_session_note_audits") == %{
             "action" => "character varying",
             "actor_user_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "notes_id" => "bigint",
             "occurred_at" => "timestamp without time zone",
             "reason" => "character varying",
             "updated_at" => "timestamp without time zone"
           }
  end

  test "defines the required namespaced Notes, Answer, and audit contract" do
    assert column_types("holistic_mentorship_post_session_notes") == %{
             "author_user_id" => "bigint",
             "first_drafted_at" => "timestamp without time zone",
             "first_submitted_at" => "timestamp without time zone",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "last_edited_at" => "timestamp without time zone",
             "phase_id" => "bigint",
             "revision" => "integer",
             "state" => "character varying",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert column_types("holistic_mentorship_post_session_answers") == %{
             "answer" => "text",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "notes_id" => "bigint",
             "question_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns("holistic_mentorship_post_session_notes") == [
             "first_submitted_at"
           ]

    assert nullable_columns("holistic_mentorship_post_session_answers") == []

    assert nullable_columns("holistic_mentorship_post_session_note_audits") == ["reason"]

    assert foreign_keys("holistic_mentorship_post_session_notes") == [
             {"author_user_id", "user", "NO ACTION"},
             {"phase_id", "holistic_mentorship_phases", "NO ACTION"},
             {"student_id", "student", "NO ACTION"}
           ]

    assert foreign_keys("holistic_mentorship_post_session_answers") == [
             {"notes_id", "holistic_mentorship_post_session_notes", "NO ACTION"},
             {"question_id", "holistic_mentorship_phase_questions", "NO ACTION"}
           ]

    assert foreign_keys("holistic_mentorship_post_session_note_audits") == [
             {"actor_user_id", "user", "NO ACTION"},
             {"notes_id", "holistic_mentorship_post_session_notes", "NO ACTION"}
           ]
  end

  test "retains used Notes records and mutation audits" do
    scope = insert_scope()
    {:ok, %{rows: [[notes_id]]}} = insert_note(scope, "draft", 1, nil)
    assert {:ok, _} = insert_answer(notes_id, Enum.at(scope.question_ids, 0), "Current answer")

    [[audit_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_post_session_note_audits
          (notes_id, actor_user_id, action, occurred_at)
        VALUES ($1, $2, 'draft_saved', now())
        RETURNING id
        """,
        [notes_id, scope.author_user_id]
      ).rows

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM holistic_mentorship_post_session_note_audits WHERE id = $1", [
        audit_id
      ])
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query(
        "UPDATE holistic_mentorship_post_session_note_audits SET action = 'changed' WHERE id = $1",
        [audit_id]
      )
    end)

    for {table, id} <- [
          {"student", scope.student_id},
          {"user", scope.author_user_id},
          {"holistic_mentorship_phases", scope.phase_id},
          {"holistic_mentorship_phase_questions", Enum.at(scope.question_ids, 0)},
          {"holistic_mentorship_post_session_notes", notes_id}
        ] do
      assert_constraint(:foreign_key_violation, fn ->
        Repo.query("DELETE FROM \"#{table}\" WHERE id = $1", [id])
      end)
    end
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM Notes', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM Notes', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[grade_id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES (11, now(), now()) RETURNING id"
      ).rows

    {:ok, {phase_id, question_ids}} =
      Repo.transaction(fn ->
        [[plan_id]] =
          Repo.query!(
            "INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year) VALUES ($1, '2026-27') RETURNING id",
            [program_id]
          ).rows

        [[phase_id]] =
          Repo.query!(
            """
            INSERT INTO holistic_mentorship_phases
              (phase_plan_id, grade_id, title, position, state, guidance_markdown, revision)
            VALUES ($1, $2, 'HM Notes Phase', 1, 'open', 'Guidance', 1)
            RETURNING id
            """,
            [plan_id, grade_id]
          ).rows

        question_ids =
          Repo.query!(
            """
            INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position)
            VALUES ($1, 'Reflect', 1), ($1, 'Plan', 2)
            RETURNING id
            """,
            [phase_id]
          ).rows
          |> Enum.map(fn [id] -> id end)

        {phase_id, question_ids}
      end)

    %{
      author_user_id: author_user_id,
      phase_id: phase_id,
      question_ids: question_ids,
      student_id: student_id
    }
  end

  defp insert_note(scope, state, revision, first_submitted_at) do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_post_session_notes
        (student_id, phase_id, author_user_id, state, revision,
         first_drafted_at, first_submitted_at, last_edited_at)
      VALUES ($1, $2, $3, $4, $5, '2026-07-16 10:00:00', $6, '2026-07-16 12:00:00')
      RETURNING id
      """,
      [
        scope.student_id,
        scope.phase_id,
        scope.author_user_id,
        state,
        revision,
        first_submitted_at
      ]
    )
  end

  defp insert_answer(notes_id, question_id, answer) do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_post_session_answers (notes_id, question_id, answer)
      VALUES ($1, $2, $3)
      """,
      [notes_id, question_id, answer]
    )
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

  defp foreign_keys(table) do
    Repo.query!(
      """
      SELECT kcu.column_name, ccu.table_name, rc.delete_rule
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name AND rc.constraint_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name = $1
      ORDER BY kcu.column_name
      """,
      [table]
    ).rows
    |> Enum.map(fn [column, referenced_table, delete_rule] ->
      {column, referenced_table, delete_rule}
    end)
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
