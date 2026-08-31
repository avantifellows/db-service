defmodule Dbservice.HolisticMentorshipPrivacySchemaTest do
  use Dbservice.DataCase, async: true

  @table "holistic_mentorship_privacy_deletions"

  import Dbservice.UsersFixtures

  test "stores one durable content-free privacy tombstone per Student" do
    assert Repo.query!(
             """
             SELECT column_name, data_type, is_nullable
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = $1
             ORDER BY ordinal_position
             """,
             [@table]
           ).rows == [
             ["id", "bigint", "NO"],
             ["student_id", "bigint", "NO"],
             ["actor_user_id", "bigint", "NO"],
             ["reason", "text", "NO"],
             ["profile_summaries_erased", "integer", "NO"],
             ["post_session_answers_erased", "integer", "NO"],
             ["historical_answers_erased", "integer", "NO"],
             ["occurred_at", "timestamp without time zone", "NO"],
             ["inserted_at", "timestamp without time zone", "NO"],
             ["updated_at", "timestamp without time zone", "NO"]
           ]

    assert Repo.query!(
             """
             SELECT a.attname, f.confdeltype
             FROM pg_constraint f
             JOIN pg_attribute a ON a.attrelid = f.conrelid AND a.attnum = ANY(f.conkey)
             WHERE f.conrelid = to_regclass($1) AND f.contype = 'f'
             ORDER BY a.attname
             """,
             [@table]
           ).rows == [["actor_user_id", "a"], ["student_id", "a"]]

    assert Repo.query!(
             """
             SELECT conname FROM pg_constraint
             WHERE conrelid = to_regclass($1) AND contype = 'c'
             """,
             [@table]
           ).rows == [["hm_privacy_deletions_content_check"]]

    assert Repo.query!(
             """
             SELECT indexname FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = $1
             ORDER BY indexname
             """,
             [@table]
           ).rows == [
             ["hm_privacy_deletions_student_uidx"],
             ["holistic_mentorship_privacy_deletions_pkey"]
           ]

    assert Repo.query!(
             """
             SELECT indexdef FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = $1
               AND indexname = 'hm_privacy_deletions_student_uidx'
             """,
             [@table]
           ).rows == [
             [
               "CREATE UNIQUE INDEX hm_privacy_deletions_student_uidx ON public.holistic_mentorship_privacy_deletions USING btree (student_id)"
             ]
           ]

    assert Repo.query!(
             """
             SELECT trigger_name FROM information_schema.triggers
             WHERE event_object_schema = 'public'
               AND trigger_name IN (
                 'hm_privacy_deletions_immutable',
                 'hm_profile_summaries_privacy_guard',
                 'hm_post_session_answers_privacy_guard',
                 'hm_historical_note_answers_privacy_guard'
               )
             GROUP BY trigger_name
             ORDER BY trigger_name
             """,
             []
           ).rows == [
             ["hm_historical_note_answers_privacy_guard"],
             ["hm_post_session_answers_privacy_guard"],
             ["hm_privacy_deletions_immutable"],
             ["hm_profile_summaries_privacy_guard"]
           ]

    assert Repo.query!(
             """
             SELECT pg_get_functiondef(
               'holistic_mentorship_reject_erased_student_content()'::regprocedure
             ) LIKE '%pg_advisory_xact_lock(target_student_id::integer, 0)%'
             """,
             []
           ).rows == [[true]]
  end

  test "allows a zero-content tombstone once and protects it from mutation" do
    {_student_user, student} = student_fixture()
    actor = user_fixture()

    assert Repo.query!(
             """
             INSERT INTO #{@table}
               (student_id, actor_user_id, reason, profile_summaries_erased,
                post_session_answers_erased, historical_answers_erased, occurred_at)
             VALUES ($1, $2, 'approved-request', 0, 0, 0, now())
             RETURNING student_id
             """,
             [student.id, actor.id]
           ).rows == [[student.id]]

    assert_postgres_error(:unique_violation, fn ->
      Repo.query(
        """
        INSERT INTO #{@table}
          (student_id, actor_user_id, reason, profile_summaries_erased,
           post_session_answers_erased, historical_answers_erased, occurred_at)
        VALUES ($1, $2, 'duplicate-request', 0, 0, 0, now())
        """,
        [student.id, actor.id]
      )
    end)

    for operation <- [
          fn ->
            Repo.query("UPDATE #{@table} SET reason = 'changed' WHERE student_id = $1", [
              student.id
            ])
          end,
          fn -> Repo.query("DELETE FROM #{@table} WHERE student_id = $1", [student.id]) end
        ] do
      assert_postgres_error(:check_violation, operation)
    end
  end

  defp assert_postgres_error(code, operation) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(operation.()) end, mode: :savepoint)
  end
end
