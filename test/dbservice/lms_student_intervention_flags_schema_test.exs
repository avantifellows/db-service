defmodule Dbservice.LmsStudentInterventionFlagsSchemaTest do
  use Dbservice.DataCase, async: false

  test "allows at most one open flag per Student" do
    scope = insert_scope()
    assert {:ok, _} = insert_flag(scope, "open", nil)

    assert_constraint(:unique_violation, fn -> insert_flag(scope, "open", nil) end)

    assert {:ok, _} = insert_flag(scope, "resolved", ~U[2026-09-25 10:00:00Z])
    assert {:ok, _} = insert_flag(scope, "resolved", ~U[2026-09-25 11:00:00Z])
  end

  test "keeps status and resolved_at consistent" do
    scope = insert_scope()

    assert_constraint(:check_violation, fn -> insert_flag(scope, "escalated", nil) end)
    assert_constraint(:check_violation, fn -> insert_flag(scope, "resolved", nil) end)

    assert_constraint(:check_violation, fn ->
      insert_flag(scope, "open", ~U[2026-09-25 10:00:00Z])
    end)
  end

  test "rejects unknown statuses on update rows" do
    flag_id = insert_open_flag!()

    assert_constraint(:check_violation, fn ->
      insert_update(flag_id, "note", "open", "escalated")
    end)
  end

  test "update rows are append-only except clearing the body" do
    flag_id = insert_open_flag!()
    {:ok, %{rows: [[update_id]]}} = insert_update(flag_id, "Lost a parent", nil, "open")

    assert_constraint(:check_violation, fn ->
      Repo.query(
        "UPDATE lms_student_intervention_flag_updates SET body = 'edited' WHERE id = $1",
        [update_id]
      )
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query(
        "UPDATE lms_student_intervention_flag_updates SET body = NULL, status_to = 'resolved' WHERE id = $1",
        [update_id]
      )
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM lms_student_intervention_flag_updates WHERE id = $1", [update_id])
    end)

    assert Repo.query!(
             "UPDATE lms_student_intervention_flag_updates SET body = NULL WHERE id = $1 RETURNING status_to",
             [update_id]
           ).rows == [["open"]]
  end

  defp insert_open_flag! do
    {:ok, %{rows: [[flag_id]]}} = insert_flag(insert_scope(), "open", nil)
    flag_id
  end

  defp insert_scope do
    [[student_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [student_user_id]
      ).rows

    [[school_id]] =
      Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    %{student_id: student_id, school_id: school_id}
  end

  defp insert_flag(scope, status, resolved_at) do
    Repo.query(
      """
      INSERT INTO lms_student_intervention_flags
        (student_id, school_id, status, raised_by_email, resolved_at)
      VALUES ($1, $2, $3, 'teacher@avantifellows.org', $4)
      RETURNING id
      """,
      [scope.student_id, scope.school_id, status, resolved_at]
    )
  end

  defp insert_update(flag_id, body, status_from, status_to) do
    Repo.query(
      """
      INSERT INTO lms_student_intervention_flag_updates
        (flag_id, author_email, body, status_from, status_to)
      VALUES ($1, 'teacher@avantifellows.org', $2, $3, $4)
      RETURNING id
      """,
      [flag_id, body, status_from, status_to]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
