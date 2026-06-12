defmodule Dbservice.StaffPositionsSchemaTest do
  use Dbservice.DataCase, async: true

  describe "staff / centre_positions / teacher / user_permission schema" do
    test "exposes staff and centre position tables with required constraints" do
      assert Map.keys(columns("staff")) |> Enum.sort() == [
               "designation",
               "employee_code",
               "exit_date",
               "id",
               "inserted_at",
               "staff_type",
               "updated_at",
               "user_id"
             ]

      assert Map.keys(columns("centre_positions")) |> Enum.sort() == [
               "centre_id",
               "deleted_at",
               "hr_code",
               "id",
               "inserted_at",
               "notes",
               "role",
               "updated_at",
               "user_id"
             ]

      assert_required_columns("staff", [
        "id",
        "user_id",
        "employee_code",
        "staff_type",
        "inserted_at",
        "updated_at"
      ])

      assert_required_columns("centre_positions", [
        "id",
        "centre_id",
        "role",
        "inserted_at",
        "updated_at"
      ])

      assert columns("staff")["designation"].nullable?
      assert columns("staff")["exit_date"].nullable?
      assert columns("centre_positions")["user_id"].nullable?
      assert columns("centre_positions")["hr_code"].nullable?
      assert columns("centre_positions")["deleted_at"].nullable?

      assert ["employee_code"] in unique_indexes("staff")
      assert ["user_id"] in unique_indexes("staff")
      assert indexes("staff") |> Enum.any?(&(&1 == ["staff_type"]))

      assert indexes("centre_positions") |> Enum.any?(&(&1 == ["centre_id"]))
      assert indexes("centre_positions") |> Enum.any?(&(&1 == ["user_id"]))
      assert ["centre_id", "role", "user_id"] in unique_indexes("centre_positions")

      # The active-assignment uniqueness is PARTIAL: vacant seats (user_id
      # NULL) and soft-deleted history rows must not collide.
      assert {:ok, %{rows: [[true]]}} =
               Repo.query(
                 """
                 SELECT pg_get_indexdef(i.oid) ILIKE '%WHERE %deleted_at IS NULL%user_id IS NOT NULL%'
                 FROM pg_class i
                 WHERE i.relname = 'centre_positions_active_assignment_unique'
                 """,
                 []
               )

      assert foreign_keys("staff") == [{"user_id", "user", "id"}]

      assert foreign_keys("centre_positions") == [
               {"centre_id", "centres", "id"},
               {"user_id", "user", "id"}
             ]
    end

    test "teacher_id is optional, unique, and teacher gains exit_date" do
      assert columns("teacher")["teacher_id"].nullable?
      assert columns("teacher")["exit_date"].nullable?
      assert ["teacher_id"] in unique_indexes("teacher")
    end

    test "user_permission links to user and supports revocation" do
      assert columns("user_permission")["user_id"].nullable?
      assert columns("user_permission")["revoked_at"].nullable?
      assert indexes("user_permission") |> Enum.any?(&(&1 == ["user_id"]))

      assert {"user_id", "user", "id"} in foreign_keys("user_permission")
    end
  end

  defp assert_required_columns(table, names) do
    table_columns = columns(table)

    for name <- names do
      refute table_columns[name].nullable?, "#{table}.#{name} should be NOT NULL"
    end
  end

  defp columns(table) do
    {:ok, result} =
      Repo.query(
        """
        SELECT column_name, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = $1
        ORDER BY column_name
        """,
        [table]
      )

    Map.new(result.rows, fn [name, nullable] ->
      {name, %{nullable?: nullable == "YES"}}
    end)
  end

  defp indexes(table) do
    table
    |> index_rows()
    |> Enum.map(fn {_name, _unique?, columns} -> columns end)
  end

  defp unique_indexes(table) do
    table
    |> index_rows()
    |> Enum.filter(fn {_name, unique?, _columns} -> unique? end)
    |> Enum.map(fn {_name, _unique?, columns} -> columns end)
  end

  defp index_rows(table) do
    {:ok, result} =
      Repo.query(
        """
        SELECT
          i.relname,
          ix.indisunique,
          array_agg(a.attname ORDER BY array_position(ix.indkey::int[], a.attnum)) AS columns
        FROM pg_class t
        JOIN pg_index ix ON t.oid = ix.indrelid
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
        WHERE t.relname = $1
        GROUP BY i.relname, ix.indisunique
        ORDER BY i.relname
        """,
        [table]
      )

    Enum.map(result.rows, fn [name, unique?, columns] ->
      {name, unique?, columns}
    end)
  end

  defp foreign_keys(table) do
    {:ok, result} =
      Repo.query(
        """
        SELECT
          kcu.column_name,
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND tc.table_name = $1
        ORDER BY kcu.column_name
        """,
        [table]
      )

    Enum.map(result.rows, fn [column, foreign_table, foreign_column] ->
      {column, foreign_table, foreign_column}
    end)
  end
end
