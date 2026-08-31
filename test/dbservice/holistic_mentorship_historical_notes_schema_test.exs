defmodule Dbservice.HolisticMentorshipHistoricalNotesSchemaTest do
  use Dbservice.DataCase, async: false

  @notes "holistic_mentorship_historical_notes"
  @answers "holistic_mentorship_historical_note_answers"

  test "defines the namespaced Historical Notes provenance contract" do
    assert column_types(@notes) == %{
             "id" => "bigint",
             "imported_at" => "timestamp without time zone",
             "imported_by_user_id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "mentor_user_id" => "bigint",
             "reconciliation_metadata" => "jsonb",
             "source_fingerprint" => "character varying",
             "source_record_key" => "character varying",
             "source_system" => "character varying",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert column_types(@answers) == %{
             "answer" => "text",
             "historical_note_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "position" => "integer",
             "question" => "text",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns(@notes) == ["mentor_user_id"]
    assert nullable_columns(@answers) == ["answer"]

    assert foreign_keys(@notes) == [
             {"imported_by_user_id", "user", "NO ACTION"},
             {"mentor_user_id", "user", "NO ACTION"},
             {"student_id", "student", "NO ACTION"}
           ]

    assert foreign_keys(@answers) == [
             {"historical_note_id", @notes, "NO ACTION"}
           ]
  end

  test "uses Student and source system as the idempotent provenance identity" do
    scope = insert_scope()
    assert {:ok, _} = insert_note(scope, "legacy-row-1")

    assert_constraint(:unique_violation, fn ->
      insert_note(scope, "different-legacy-row")
    end)
  end

  test "requires exactly four ordered source Questions and permits partial answers" do
    {incomplete_result, rows} =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        incomplete_scope = insert_scope()
        scope = insert_scope()

        try do
          incomplete_result = commit_note(incomplete_scope, "incomplete", [nil, nil, nil])

          {:ok, note_id} =
            commit_note(scope, "complete", [nil, "A partial answer", nil, nil])

          rows =
            Repo.query!(
              """
              SELECT position, question, answer
              FROM holistic_mentorship_historical_note_answers
              WHERE historical_note_id = $1
              ORDER BY position
              """,
              [note_id]
            ).rows

          {incomplete_result, rows}
        after
          delete_scope(incomplete_scope)
          delete_scope(scope)
        end
      end)

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = incomplete_result

    assert rows == [
             [1, "Legacy question 1", nil],
             [2, "Legacy question 2", "A partial answer"],
             [3, "Legacy question 3", nil],
             [4, "Legacy question 4", nil]
           ]
  end

  test "allows an unmatched Mentor and restricts canonical provenance deletion" do
    nullable_mentor_scope = insert_scope() |> Map.put(:mentor_user_id, nil)
    nullable_note_id = insert_note_id!(nullable_mentor_scope, "nullable-mentor")

    for position <- 1..4 do
      insert_answer!(nullable_note_id, position, nil)
    end

    assert Repo.query!(
             "SELECT mentor_user_id FROM holistic_mentorship_historical_notes WHERE id = $1",
             [nullable_note_id]
           ).rows == [[nil]]

    scope = insert_scope()
    note_id = insert_note_id!(scope, "protected-provenance")

    for position <- 1..4 do
      insert_answer!(note_id, position, nil)
    end

    for {table, id} <- [
          {"student", scope.student_id},
          {"user", scope.mentor_user_id},
          {"user", scope.imported_by_user_id}
        ] do
      assert_constraint(:foreign_key_violation, fn ->
        Repo.query("DELETE FROM \"#{table}\" WHERE id = $1", [id])
      end)
    end
  end

  test "limits each Historical Notes source position to one row from one through four" do
    scope = insert_scope()
    note_id = insert_note_id!(scope, "ordered-source")

    assert_constraint(:check_violation, fn -> insert_answer(note_id, 0, nil) end)

    insert_answer!(note_id, 1, nil)

    assert_constraint(:unique_violation, fn ->
      insert_answer(note_id, 1, "Duplicate position")
    end)
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

  defp insert_scope do
    [[student_user_id], [mentor_user_id], [imported_by_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()), (now(), now()), (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [student_user_id]
      ).rows

    %{
      imported_by_user_id: imported_by_user_id,
      mentor_user_id: mentor_user_id,
      student_id: student_id,
      student_user_id: student_user_id
    }
  end

  defp insert_note(scope, source_record_key) do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_historical_notes
        (student_id, mentor_user_id, source_system, source_record_key, source_fingerprint,
         imported_by_user_id, imported_at, reconciliation_metadata)
      VALUES ($1, $2, 'legacy_holistic_notes', $3, 'sha256:known', $4,
              '2026-07-16 10:00:00', '{"match":"canonical_user"}')
      RETURNING id
      """,
      [scope.student_id, scope.mentor_user_id, source_record_key, scope.imported_by_user_id]
    )
  end

  defp insert_note_id!(scope, source_record_key) do
    {:ok, %{rows: [[id]]}} = insert_note(scope, source_record_key)
    id
  end

  defp insert_answer!(note_id, position, answer) do
    {:ok, result} = insert_answer(note_id, position, answer)
    result
  end

  defp insert_answer(note_id, position, answer) do
    Repo.query(
      """
      INSERT INTO holistic_mentorship_historical_note_answers
        (historical_note_id, position, question, answer)
      VALUES ($1, $2, $3, $4)
      """,
      [note_id, position, "Legacy question #{position}", answer]
    )
  end

  defp commit_note(scope, source_record_key, answers) do
    Repo.transaction(fn ->
      note_id = insert_note_id!(scope, source_record_key)

      answers
      |> Enum.with_index(1)
      |> Enum.each(fn {answer, position} -> insert_answer!(note_id, position, answer) end)

      note_id
    end)
  rescue
    error in Postgrex.Error -> {:error, error}
  end

  defp delete_scope(scope) do
    Repo.transaction(fn ->
      Repo.query!(
        "DELETE FROM holistic_mentorship_historical_note_answers WHERE historical_note_id IN (SELECT id FROM holistic_mentorship_historical_notes WHERE student_id = $1)",
        [scope.student_id]
      )

      Repo.query!("DELETE FROM holistic_mentorship_historical_notes WHERE student_id = $1", [
        scope.student_id
      ])
    end)

    Repo.query!("DELETE FROM student WHERE id = $1", [scope.student_id])

    Repo.query!("DELETE FROM \"user\" WHERE id = ANY($1)", [
      [scope.student_user_id, scope.mentor_user_id, scope.imported_by_user_id]
    ])
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
