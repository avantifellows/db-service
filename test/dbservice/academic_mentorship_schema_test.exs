defmodule Dbservice.AcademicMentorshipSchemaTest do
  use Dbservice.DataCase, async: true

  @tables [
    "acad_mentorship_runtime_settings",
    "acad_mentorship_prompt_versions",
    "acad_mentorship_tests_to_consider",
    "acad_mentorship_teacher_feedback",
    "acad_mentorship_cutoff_rows",
    "acad_mentorship_benchmark_students",
    "acad_mentorship_reference_reports",
    "acad_mentorship_inference_sessions",
    "acad_mentorship_inference_items",
    "acad_mentorship_inference_item_files",
    "acad_mentorship_scoring_criteria",
    "acad_mentorship_eval_runs",
    "acad_mentorship_eval_run_benchmarks",
    "acad_mentorship_eval_run_scoring_criteria",
    "acad_mentorship_eval_scores"
  ]

  @identity_tables @tables -- ["acad_mentorship_runtime_settings"]

  describe "Academic Mentorship schema" do
    test "creates the LMS Academic Mentor-Mentee Mapping table" do
      table = "academic_mentorship_mentor_mentee_mappings"

      assert table in table_names()

      assert Map.keys(columns(table)) |> Enum.sort() == [
               "academic_year",
               "assigned_at",
               "assigned_by_user_id",
               "end_reason",
               "ended_at",
               "ended_by_user_id",
               "id",
               "inserted_at",
               "mentor_user_id",
               "program_id",
               "school_id",
               "student_id",
               "updated_at"
             ]

      assert_required_columns(table, [
        "id",
        "school_id",
        "academic_year",
        "mentor_user_id",
        "student_id",
        "assigned_at",
        "assigned_by_user_id",
        "inserted_at",
        "updated_at"
      ])

      assert columns(table)["id"].type == "bigint"
      assert columns(table)["program_id"].nullable?
      assert columns(table)["ended_at"].nullable?
      assert columns(table)["ended_by_user_id"].nullable?
      assert columns(table)["end_reason"].nullable?

      assert foreign_keys(table) == [
               {"assigned_by_user_id", "user", "id"},
               {"ended_by_user_id", "user", "id"},
               {"mentor_user_id", "user", "id"},
               {"program_id", "program", "id"},
               {"school_id", "school", "id"},
               {"student_id", "student", "id"}
             ]

      assert index_def("am_mentor_mentee_active_mentee_unique") =~ "UNIQUE INDEX"

      assert index_def("am_mentor_mentee_active_mentee_unique") =~
               "(school_id, academic_year, student_id)"

      assert index_def("am_mentor_mentee_active_mentee_unique") =~ "WHERE (ended_at IS NULL)"

      assert index_def("am_mentor_mentee_school_year_active_idx") =~
               "(school_id, academic_year)"

      assert index_def("am_mentor_mentee_school_year_active_idx") =~ "WHERE (ended_at IS NULL)"

      assert index_def("am_mentor_mentee_mentor_year_active_idx") =~
               "(mentor_user_id, academic_year)"

      assert index_def("am_mentor_mentee_mentor_year_active_idx") =~
               "WHERE (ended_at IS NULL)"

      assert ["mentor_user_id"] in indexes(table)
    end

    test "creates the full phase-1 table set" do
      existing_tables = table_names()

      for table <- @tables do
        assert table in existing_tables
      end
    end

    test "uses identity bigint primary keys for workflow tables" do
      for table <- @identity_tables do
        id = columns(table)["id"]

        assert id.type == "bigint", "#{table}.id should be bigint"
        assert id.identity?, "#{table}.id should be generated identity"
        refute id.nullable?, "#{table}.id should be required"
      end

      runtime_id = columns("acad_mentorship_runtime_settings")["id"]
      assert runtime_id.type == "character varying"
      refute runtime_id.nullable?

      assert check_names("acad_mentorship_runtime_settings")
             |> Enum.member?("am_runtime_settings_singleton_check")
    end

    test "seeds the singleton runtime settings row" do
      result =
        Repo.query!(
          """
          SELECT id
          FROM acad_mentorship_runtime_settings
          WHERE id = 'global'
          """,
          []
        )

      assert result.rows == [["global"]]
    end

    test "exposes core workflow columns expected by AI Mentorship Guide" do
      assert_required_columns("acad_mentorship_inference_sessions", [
        "id",
        "status",
        "is_eval",
        "created_at",
        "updated_at"
      ])

      assert Map.keys(columns("acad_mentorship_inference_items")) |> Enum.sort() == [
               "completed_at",
               "created_at",
               "current_step",
               "duration_ms",
               "error_message",
               "error_type",
               "id",
               "is_retry",
               "last_progress_at",
               "latest_test_id",
               "no_data_reason",
               "pipeline_completion_tokens",
               "pipeline_cost_usd",
               "pipeline_prompt_tokens",
               "pipeline_total_tokens",
               "retry_of_item_id",
               "selected_test_ids",
               "session_id",
               "started_at",
               "status",
               "student_id",
               "updated_at",
               "validation_completion_tokens",
               "validation_cost_usd",
               "validation_prompt_tokens",
               "validation_total_tokens",
               "validation_verdict"
             ]

      assert_required_columns("acad_mentorship_inference_items", [
        "id",
        "session_id",
        "student_id",
        "status",
        "is_retry",
        "pipeline_cost_usd",
        "validation_cost_usd",
        "created_at",
        "updated_at"
      ])

      assert columns("acad_mentorship_teacher_feedback")["feedback"].type == "jsonb"
      assert columns("acad_mentorship_inference_items")["selected_test_ids"].type == "jsonb"
      assert columns("acad_mentorship_inference_item_files")["byte_size"].type == "bigint"
    end

    test "adds foreign keys between existing Main DB tables and mentorship tables" do
      assert {"program_id", "program", "id"} in foreign_keys("acad_mentorship_inference_sessions")
      assert {"student_id", "student", "id"} in foreign_keys("acad_mentorship_inference_items")

      assert {"session_id", "acad_mentorship_inference_sessions", "id"} in foreign_keys(
               "acad_mentorship_inference_items"
             )

      assert {"item_id", "acad_mentorship_inference_items", "id"} in foreign_keys(
               "acad_mentorship_inference_item_files"
             )

      assert {"benchmark_student_id", "acad_mentorship_benchmark_students", "id"} in foreign_keys(
               "acad_mentorship_reference_reports"
             )

      assert {"eval_run_id", "acad_mentorship_eval_runs", "id"} in foreign_keys(
               "acad_mentorship_eval_run_benchmarks"
             )

      assert {"scoring_criterion_id", "acad_mentorship_scoring_criteria", "id"} in foreign_keys(
               "acad_mentorship_eval_scores"
             )
    end

    test "adds the required status, range, and lifecycle check constraints" do
      assert "am_sessions_status_check" in check_names("acad_mentorship_inference_sessions")
      assert "am_items_status_check" in check_names("acad_mentorship_inference_items")
      assert "am_items_validation_verdict_check" in check_names("acad_mentorship_inference_items")
      assert "am_items_token_counts_check" in check_names("acad_mentorship_inference_items")
      assert "am_items_costs_check" in check_names("acad_mentorship_inference_items")
      assert "am_prompt_versions_type_check" in check_names("acad_mentorship_prompt_versions")

      assert "am_reference_reports_status_check" in check_names(
               "acad_mentorship_reference_reports"
             )

      assert "am_eval_runs_status_check" in check_names("acad_mentorship_eval_runs")

      assert "am_eval_benchmarks_status_check" in check_names(
               "acad_mentorship_eval_run_benchmarks"
             )

      assert check_def("acad_mentorship_eval_run_benchmarks", "am_eval_benchmarks_status_check") =~
               "'scoring'::character varying"

      assert "am_eval_scores_score_check" in check_names("acad_mentorship_eval_scores")
    end

    test "adds active-row and lookup indexes" do
      assert index_def("am_tests_to_consider_active_unique") =~ "WHERE (deleted_at IS NULL)"
      assert index_def("am_teacher_feedback_active_unique") =~ "WHERE (deleted_at IS NULL)"
      assert index_def("am_prompt_versions_one_active") =~ "WHERE"
      assert index_def("am_benchmark_students_active_unique") =~ "WHERE (is_active IS TRUE)"
      assert index_def("am_reference_reports_one_approved") =~ "WHERE"
      assert index_def("am_items_original_student_unique") =~ "WHERE (is_retry IS FALSE)"
      assert index_def("am_eval_scores_active_unique") =~ "WHERE (is_superseded IS FALSE)"

      assert ["session_id"] in indexes("acad_mentorship_inference_items")
      assert ["student_id"] in indexes("acad_mentorship_inference_items")
      assert ["item_id", "file_kind"] in indexes("acad_mentorship_inference_item_files")
      assert ["status"] in indexes("acad_mentorship_eval_runs")
      assert ["scoring_status"] in indexes("acad_mentorship_eval_run_benchmarks")
    end
  end

  defp assert_required_columns(table, names) do
    table_columns = columns(table)

    for name <- names do
      refute table_columns[name].nullable?, "#{table}.#{name} should be NOT NULL"
    end
  end

  defp table_names do
    Repo.query!(
      """
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      """,
      []
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp columns(table) do
    Repo.query!(
      """
      SELECT column_name, is_nullable, data_type, udt_name, is_identity
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      ORDER BY column_name
      """,
      [table]
    ).rows
    |> Map.new(fn [name, nullable, type, udt_name, identity] ->
      type_name = if type == "USER-DEFINED", do: udt_name, else: type

      {name, %{nullable?: nullable == "YES", type: type_name, identity?: identity == "YES"}}
    end)
  end

  defp indexes(table) do
    table
    |> index_rows()
    |> Enum.map(fn {_name, _unique?, columns} -> columns end)
  end

  defp index_rows(table) do
    Repo.query!(
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
    ).rows
    |> Enum.map(fn [name, unique?, columns] ->
      {name, unique?, columns}
    end)
  end

  defp index_def(index_name) do
    Repo.query!(
      """
      SELECT indexdef
      FROM pg_indexes
      WHERE schemaname = 'public' AND indexname = $1
      """,
      [index_name]
    ).rows
    |> List.first()
    |> then(fn [definition] -> definition end)
  end

  defp check_names(table) do
    Repo.query!(
      """
      SELECT tc.constraint_name
      FROM information_schema.table_constraints tc
      WHERE tc.constraint_type = 'CHECK'
        AND tc.table_schema = 'public'
        AND tc.table_name = $1
      ORDER BY tc.constraint_name
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp check_def(table, constraint_name) do
    Repo.query!(
      """
      SELECT pg_get_constraintdef(c.oid)
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'public'
        AND t.relname = $1
        AND c.conname = $2
      """,
      [table, constraint_name]
    ).rows
    |> List.first()
    |> then(fn [definition] -> definition end)
  end

  defp foreign_keys(table) do
    Repo.query!(
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
    ).rows
    |> Enum.map(fn [column, foreign_table, foreign_column] ->
      {column, foreign_table, foreign_column}
    end)
  end
end
