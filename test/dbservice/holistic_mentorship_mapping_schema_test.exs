defmodule Dbservice.HolisticMentorshipMappingSchemaTest do
  use Dbservice.DataCase, async: false

  alias Dbservice.HolisticMentorship

  @table "holistic_mentorship_mentor_mentee_mappings"

  test "defines the canonical Mapping contract and indexes" do
    assert column_types() == %{
             "academic_year" => "character varying",
             "assigned_by_user_id" => "bigint",
             "assignment_source" => "character varying",
             "end_reason" => "character varying",
             "end_source" => "character varying",
             "ended_at" => "timestamp without time zone",
             "ended_by_user_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "mentor_user_id" => "bigint",
             "program_id" => "bigint",
             "school_id" => "bigint",
             "started_at" => "timestamp without time zone",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns() == [
             "assigned_by_user_id",
             "end_reason",
             "end_source",
             "ended_at",
             "ended_by_user_id"
           ]

    assert foreign_keys() == [
             {"assigned_by_user_id", "user", "NO ACTION"},
             {"ended_by_user_id", "user", "NO ACTION"},
             {"mentor_user_id", "user", "NO ACTION"},
             {"program_id", "program", "NO ACTION"},
             {"school_id", "school", "NO ACTION"},
             {"student_id", "student", "NO ACTION"}
           ]

    assert check_names() == ["hm_mappings_lifecycle_check"]

    assert indexes() == [
             {"hm_mappings_active_mentor_year_idx", false,
              ["mentor_user_id", "academic_year", "student_id"], "(ended_at IS NULL)"},
             {"hm_mappings_active_school_year_idx", false,
              ["school_id", "academic_year", "student_id"], "(ended_at IS NULL)"},
             {"hm_mappings_active_student_year_unique", true, ["student_id", "academic_year"],
              "(ended_at IS NULL)"},
             {"hm_mappings_student_history_idx", false,
              ["student_id", "academic_year", "started_at"], nil},
             {"holistic_mentorship_mentor_mentee_mappings_pkey", true, ["id"], nil}
           ]
  end

  test "enforces active and ended Mapping lifecycle states" do
    scope = insert_scope()

    invalid_lifecycles = [
      [nil, nil, "manual_removal", nil],
      [~N[2025-12-31 09:59:59], nil, "manual_removal", "af_lms"],
      [~N[2026-07-16 10:01:00], nil, nil, "af_lms"],
      [~N[2026-07-16 10:01:00], nil, "manual_removal", nil]
    ]

    for lifecycle <- invalid_lifecycles do
      assert_check_violation(fn -> insert_mapping(scope, lifecycle) end)
    end

    assert {:ok, %{rows: [[mapping_id]]}} =
             insert_mapping(scope, [
               ~N[2026-07-16 10:01:00],
               nil,
               "student_dropout",
               "db_service_student_eligibility"
             ])

    assert Repo.query!(
             "SELECT ended_by_user_id FROM #{@table} WHERE id = $1",
             [mapping_id]
           ).rows == [[nil]]

    assert_check_violation(fn ->
      Repo.query("UPDATE #{@table} SET assignment_source = '' WHERE id = $1", [mapping_id])
    end)
  end

  test "ends active Mappings once through the shared eligibility operation" do
    scope = insert_scope()
    assert {:ok, %{rows: [[mapping_id]]}} = insert_mapping(scope, [nil, nil, nil, nil])

    assert {:error, :invalid_end_reason} =
             HolisticMentorship.end_active_mappings(scope.student_id, :manual_removal)

    assert Repo.query!("SELECT ended_at FROM #{@table} WHERE id = $1", [mapping_id]).rows == [
             [nil]
           ]

    assert {:ok, {:ok, 1}} =
             Repo.transaction(fn ->
               HolisticMentorship.end_active_mappings(scope.student_id, :student_dropout)
             end)

    assert Repo.query!(
             "SELECT id, ended_at IS NOT NULL, ended_by_user_id, end_source, end_reason FROM #{@table}",
             []
           ).rows == [
             [
               mapping_id,
               true,
               nil,
               "db_service_student_eligibility",
               "student_dropout"
             ]
           ]

    assert {:ok, {:ok, 0}} =
             Repo.transaction(fn ->
               HolisticMentorship.end_active_mappings(scope.student_id, :student_dropout)
             end)

    assert Repo.query!("SELECT count(*) FROM #{@table}").rows == [[1]]
  end

  test "retains ended assignment history and restricts canonical deletion" do
    scope = insert_scope()
    assert {:ok, %{rows: [[first_id]]}} = insert_mapping(scope, [nil, nil, nil, nil])

    [[other_school_id]] =
      Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    assert_unique_violation(fn ->
      insert_mapping(%{scope | school_id: other_school_id}, [nil, nil, nil, nil])
    end)

    Repo.query!(
      """
      UPDATE #{@table}
      SET ended_at = '2026-01-02 10:00:00', ended_by_user_id = $1,
          end_source = 'af_lms', end_reason = 'reassigned'
      WHERE id = $2
      """,
      [scope.mentor_user_id, first_id]
    )

    assert {:ok, %{rows: [[second_id]]}} = insert_mapping(scope, [nil, nil, nil, nil])

    assert Repo.query!(
             "SELECT id, ended_at IS NULL FROM #{@table} ORDER BY id",
             []
           ).rows == [[first_id, false], [second_id, true]]

    assert_foreign_key_violation(fn ->
      Repo.query("DELETE FROM student WHERE id = $1", [scope.student_id])
    end)

    assert_foreign_key_violation(fn ->
      Repo.query("DELETE FROM \"user\" WHERE id = $1", [scope.mentor_user_id])
    end)
  end

  test "concurrent assignment is first-write-wins" do
    results =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        scope = insert_scope()

        try do
          parent = self()

          tasks =
            for _ <- 1..2 do
              Task.async(fn ->
                Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                  send(parent, {:ready, self()})
                  receive do: (:go -> insert_mapping(scope, [nil, nil, nil, nil]))
                end)
              end)
            end

          task_pids =
            for _ <- tasks do
              assert_receive {:ready, task_pid}
              task_pid
            end

          Enum.each(task_pids, &send(&1, :go))
          Enum.map(tasks, &Task.await/1)
        after
          delete_scope(scope)
        end
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    assert Enum.count(results, fn
             {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} -> true
             _ -> false
           end) == 1
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

  defp insert_scope do
    [[student_user_id], [mentor_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()), (now(), now()) RETURNING id"
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

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM Mapping', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM Mapping', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      product_id: product_id,
      program_id: program_id,
      school_id: school_id,
      student_id: student_id,
      student_user_id: student_user_id
    }
  end

  defp delete_scope(scope) do
    Repo.query!("DELETE FROM #{@table} WHERE student_id = $1", [scope.student_id])
    Repo.query!("DELETE FROM student WHERE id = $1", [scope.student_id])

    Repo.query!("DELETE FROM \"user\" WHERE id IN ($1, $2)", [
      scope.student_user_id,
      scope.mentor_user_id
    ])

    Repo.query!("DELETE FROM school WHERE id = $1", [scope.school_id])
    Repo.query!("DELETE FROM program WHERE id = $1", [scope.program_id])
    Repo.query!("DELETE FROM product WHERE id = $1", [scope.product_id])
  end

  defp insert_mapping(scope, [ended_at, ended_by_user_id, end_reason, end_source]) do
    Repo.query(
      """
      INSERT INTO #{@table}
        (student_id, mentor_user_id, school_id, program_id, academic_year, started_at,
         assignment_source, ended_at, ended_by_user_id, end_reason, end_source)
      VALUES ($1, $2, $3, $4, '2026-27', $5, 'af_lms', $6, $7, $8, $9)
      RETURNING id
      """,
      [
        scope.student_id,
        scope.mentor_user_id,
        scope.school_id,
        scope.program_id,
        ~N[2026-01-01 10:00:00],
        ended_at,
        ended_by_user_id,
        end_reason,
        end_source
      ]
    )
  end

  defp assert_check_violation(query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :check_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end

  defp assert_foreign_key_violation(query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end

  defp assert_unique_violation(query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
