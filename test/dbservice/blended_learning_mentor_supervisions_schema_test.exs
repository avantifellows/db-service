defmodule Dbservice.BlendedLearningMentorSupervisionsSchemaTest do
  use Dbservice.DataCase, async: false

  @table "blended_learning_mentor_supervisions"

  test "defines the Supervision contract and indexes" do
    assert column_types() == %{
             "academic_year" => "character varying",
             "assigned_by_email" => "character varying",
             "assigned_by_user_id" => "bigint",
             "assignment_audit_reason" => "character varying",
             "assignment_source" => "character varying",
             "end_audit_reason" => "character varying",
             "end_reason" => "character varying",
             "end_source" => "character varying",
             "ended_at" => "timestamp without time zone",
             "ended_by_email" => "character varying",
             "ended_by_user_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "mentor_user_id" => "bigint",
             "started_at" => "timestamp without time zone",
             "supervisor_user_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns() == [
             "assigned_by_email",
             "assigned_by_user_id",
             "assignment_audit_reason",
             "end_audit_reason",
             "end_reason",
             "end_source",
             "ended_at",
             "ended_by_email",
             "ended_by_user_id"
           ]

    assert foreign_keys() == [
             {"assigned_by_user_id", "user", "NO ACTION"},
             {"ended_by_user_id", "user", "NO ACTION"},
             {"mentor_user_id", "user", "NO ACTION"},
             {"supervisor_user_id", "user", "NO ACTION"}
           ]

    assert check_names() == [
             "blm_supervisions_audit_fields_check",
             "blm_supervisions_lifecycle_check",
             "blm_supervisions_not_self_check"
           ]

    assert indexes() == [
             {"blended_learning_mentor_supervisions_pkey", true, ["id"], nil},
             {"blm_supervisions_active_mentor_year_idx", false,
              ["mentor_user_id", "academic_year"], "(ended_at IS NULL)"},
             {"blm_supervisions_active_pair_year_unique", true,
              ["supervisor_user_id", "mentor_user_id", "academic_year"], "(ended_at IS NULL)"}
           ]
  end

  test "a supervisor can supervise several Mentors, and a Mentor have several supervisors" do
    [supervisor, other_supervisor, mentor, other_mentor] = insert_users(4)

    for {supervising, supervised} <- [
          {supervisor, mentor},
          {supervisor, other_mentor},
          {other_supervisor, mentor}
        ] do
      assert {:ok, _} = insert_supervision(supervising, supervised, %{})
    end
  end

  test "rejects a Mentor supervising themselves" do
    [mentor] = insert_users(1)
    assert_constraint(:check_violation, fn -> insert_supervision(mentor, mentor, %{}) end)
  end

  test "allows one running Supervision per pair and year, and keeps ended ones" do
    [supervisor, mentor] = insert_users(2)
    assert {:ok, %{rows: [[first_id]]}} = insert_supervision(supervisor, mentor, %{})

    assert_constraint(:unique_violation, fn -> insert_supervision(supervisor, mentor, %{}) end)

    assert {:ok, _} =
             insert_supervision(supervisor, mentor, %{academic_year: "2027-2028"})

    Repo.query!(
      """
      UPDATE #{@table}
      SET ended_at = '2026-11-01 10:00:00', ended_by_email = 'ops@example.org',
          end_source = 'af_lms_script', end_reason = 'team_changed'
      WHERE id = $1
      """,
      [first_id]
    )

    assert {:ok, %{rows: [[second_id]]}} = insert_supervision(supervisor, mentor, %{})

    assert Repo.query!(
             "SELECT id, ended_at IS NULL FROM #{@table} WHERE academic_year = '2026-2027' ORDER BY id"
           ).rows == [[first_id, false], [second_id, true]]
  end

  test "enforces the running and ended lifecycle states" do
    [supervisor, mentor] = insert_users(2)

    for attrs <- [
          %{assignment_source: ""},
          %{end_source: "af_lms_script"},
          %{ended_by_email: "ops@example.org"},
          %{ended_at: ~N[2026-11-01 10:00:00], end_reason: "team_changed"},
          %{ended_at: ~N[2026-11-01 10:00:00], end_source: "af_lms_script"},
          %{
            ended_at: ~N[2026-01-01 09:00:00],
            end_source: "af_lms_script",
            end_reason: "team_changed"
          }
        ] do
      assert_constraint(:check_violation, fn -> insert_supervision(supervisor, mentor, attrs) end)
    end

    assert {:ok, _} =
             insert_supervision(supervisor, mentor, %{
               ended_at: ~N[2026-11-01 10:00:00],
               end_source: "af_lms_script",
               end_reason: "team_changed"
             })
  end

  test "rejects blank audit fields" do
    [supervisor, mentor] = insert_users(2)

    for attrs <- [%{assigned_by_email: "  "}, %{assignment_audit_reason: "\t"}] do
      assert_constraint(:check_violation, fn -> insert_supervision(supervisor, mentor, attrs) end)
    end

    assert {:ok, _} =
             insert_supervision(supervisor, mentor, %{
               assigned_by_email: "ops@example.org",
               assignment_audit_reason: "Team lead for the 2026-2027 cohort"
             })
  end

  test "keeps the users it points at" do
    [supervisor, mentor] = insert_users(2)
    assert {:ok, _} = insert_supervision(supervisor, mentor, %{})

    for user_id <- [supervisor, mentor] do
      assert_constraint(:foreign_key_violation, fn ->
        Repo.query("DELETE FROM \"user\" WHERE id = $1", [user_id])
      end)
    end
  end

  defp insert_users(count) do
    values = Enum.map_join(1..count, ", ", fn _ -> "(now(), now())" end)

    Repo.query!("INSERT INTO \"user\" (inserted_at, updated_at) VALUES #{values} RETURNING id").rows
    |> Enum.map(fn [id] -> id end)
  end

  defp insert_supervision(supervisor_user_id, mentor_user_id, attrs) do
    {columns, values} =
      %{
        supervisor_user_id: supervisor_user_id,
        mentor_user_id: mentor_user_id,
        academic_year: "2026-2027",
        started_at: ~N[2026-04-01 00:00:00],
        assignment_source: "af_lms_script"
      }
      |> Map.merge(attrs)
      |> Enum.sort()
      |> Enum.unzip()

    placeholders = Enum.map_join(1..length(values), ", ", &"$#{&1}")

    Repo.query(
      "INSERT INTO #{@table} (#{Enum.join(columns, ", ")}) VALUES (#{placeholders}) RETURNING id",
      values
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end

  defp column_types do
    Repo.query!(
      """
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      """,
      [@table]
    ).rows
    |> Map.new(fn [name, type] -> {name, type} end)
  end

  defp nullable_columns do
    Repo.query!(
      """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1 AND is_nullable = 'YES'
      ORDER BY column_name
      """,
      [@table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp foreign_keys do
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
      [@table]
    ).rows
    |> Enum.map(fn [column, referenced_table, delete_rule] ->
      {column, referenced_table, delete_rule}
    end)
  end

  defp check_names do
    Repo.query!(
      """
      SELECT constraint_record.conname
      FROM pg_constraint AS constraint_record
      JOIN pg_class AS relation ON relation.oid = constraint_record.conrelid
      JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
      WHERE namespace.nspname = 'public'
        AND relation.relname = $1
        AND constraint_record.contype = 'c'
      ORDER BY constraint_record.conname
      """,
      [@table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp indexes do
    Repo.query!(
      """
      SELECT index_record.relname,
             index.indisunique,
             array_agg(attribute.attname ORDER BY key.ordinality),
             pg_get_expr(index.indpred, index.indrelid)
      FROM pg_index AS index
      JOIN pg_class AS table_record ON table_record.oid = index.indrelid
      JOIN pg_class AS index_record ON index_record.oid = index.indexrelid
      JOIN LATERAL unnest(index.indkey) WITH ORDINALITY AS key(attnum, ordinality) ON true
      JOIN pg_attribute AS attribute
        ON attribute.attrelid = table_record.oid AND attribute.attnum = key.attnum
      WHERE table_record.relname = $1
      GROUP BY index_record.relname, index.indisunique, index.indpred, index.indrelid
      ORDER BY index_record.relname
      """,
      [@table]
    ).rows
    |> Enum.map(fn [name, unique, columns, predicate] ->
      {name, unique, columns, predicate}
    end)
  end
end
