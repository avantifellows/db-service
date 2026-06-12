defmodule Dbservice.CentreSchemaTest do
  use Dbservice.DataCase, async: true

  describe "Centre v1 schema" do
    test "exposes centre option and centre tables with required constraints" do
      assert Map.keys(columns("centre_option_sets")) |> Enum.sort() == [
               "allow_multi",
               "code",
               "id",
               "inserted_at",
               "label",
               "sort_order",
               "updated_at"
             ]

      assert Map.keys(columns("centre_options")) |> Enum.sort() == [
               "code",
               "id",
               "inserted_at",
               "is_active",
               "label",
               "option_set_id",
               "sort_order",
               "updated_at"
             ]

      assert Map.keys(columns("centres")) |> Enum.sort() == [
               "category_code",
               "id",
               "inserted_at",
               "is_active",
               "is_physical",
               "name",
               "school_id",
               "stream_codes",
               "sub_category_code",
               "type_code",
               "updated_at"
             ]

      assert_required_columns("centre_option_sets", [
        "id",
        "code",
        "label",
        "allow_multi",
        "sort_order",
        "inserted_at",
        "updated_at"
      ])

      assert_required_columns("centre_options", [
        "id",
        "option_set_id",
        "code",
        "label",
        "sort_order",
        "is_active",
        "inserted_at",
        "updated_at"
      ])

      assert_required_columns("centres", [
        "id",
        "name",
        "stream_codes",
        "is_physical",
        "is_active",
        "inserted_at",
        "updated_at"
      ])

      assert columns("centres")["school_id"].nullable?
      assert columns("centres")["type_code"].nullable?
      assert columns("centres")["category_code"].nullable?
      assert columns("centres")["sub_category_code"].nullable?
      assert columns("centres")["stream_codes"].type == "ARRAY"
      assert columns("centres")["stream_codes"].udt_name == "_text"

      assert default_for("centre_option_sets", "allow_multi") =~ "false"
      assert default_for("centre_option_sets", "sort_order") =~ "0"
      assert default_for("centre_options", "sort_order") =~ "0"
      assert default_for("centre_options", "is_active") =~ "true"
      assert default_for("centres", "stream_codes") =~ "'{}'::text[]"
      assert default_for("centres", "is_physical") =~ "false"
      assert default_for("centres", "is_active") =~ "true"

      assert ["code"] in unique_indexes("centre_option_sets")
      assert ["option_set_id", "code"] in unique_indexes("centre_options")
      refute Enum.any?(unique_indexes("centres"), &(&1 != ["id"]))

      assert indexes("centre_options") |> Enum.any?(&(&1 == ["option_set_id"]))
      assert indexes("centres") |> Enum.any?(&(&1 == ["school_id"]))
      assert indexes("centres") |> Enum.any?(&(&1 == ["type_code"]))
      assert indexes("centres") |> Enum.any?(&(&1 == ["category_code"]))
      assert indexes("centres") |> Enum.any?(&(&1 == ["sub_category_code"]))
      assert gin_indexes("centres") |> Enum.any?(&(&1 == ["stream_codes"]))

      assert foreign_keys("centre_options") == [
               {"option_set_id", "centre_option_sets", "id"}
             ]

      assert foreign_keys("centres") == [
               {"school_id", "school", "id"}
             ]
    end
  end

  defp assert_required_columns(table, names) do
    table_columns = columns(table)

    for name <- names do
      refute table_columns[name].nullable?, "#{table}.#{name} should be NOT NULL"
    end
  end

  defp default_for(table, column) do
    columns(table)[column].default || ""
  end

  defp columns(table) do
    {:ok, result} =
      Repo.query(
        """
        SELECT column_name, is_nullable, data_type, udt_name, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = $1
        ORDER BY column_name
        """,
        [table]
      )

    Map.new(result.rows, fn [name, nullable, type, udt_name, default] ->
      {name, %{nullable?: nullable == "YES", type: type, udt_name: udt_name, default: default}}
    end)
  end

  defp indexes(table) do
    table
    |> index_rows()
    |> Enum.map(fn {_name, _unique?, _method, columns} -> columns end)
  end

  defp unique_indexes(table) do
    table
    |> index_rows()
    |> Enum.filter(fn {_name, unique?, _method, _columns} -> unique? end)
    |> Enum.map(fn {_name, _unique?, _method, columns} -> columns end)
  end

  defp gin_indexes(table) do
    table
    |> index_rows()
    |> Enum.filter(fn {_name, _unique?, method, _columns} -> method == "gin" end)
    |> Enum.map(fn {_name, _unique?, _method, columns} -> columns end)
  end

  defp index_rows(table) do
    {:ok, result} =
      Repo.query(
        """
        SELECT
          i.relname,
          ix.indisunique,
          am.amname,
          array_agg(a.attname ORDER BY array_position(ix.indkey::int[], a.attnum)) AS columns
        FROM pg_class t
        JOIN pg_index ix ON t.oid = ix.indrelid
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_am am ON am.oid = i.relam
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
        WHERE t.relname = $1
        GROUP BY i.relname, ix.indisunique, am.amname
        ORDER BY i.relname
        """,
        [table]
      )

    Enum.map(result.rows, fn [name, unique?, method, columns] ->
      {name, unique?, method, columns}
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
