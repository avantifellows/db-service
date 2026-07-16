defmodule Dbservice.HolisticMentorshipPhaseSchemaTest do
  use Dbservice.DataCase, async: false

  @expected_columns %{
    "holistic_mentorship_phase_plans" => [
      "academic_year",
      "id",
      "inserted_at",
      "program_id",
      "updated_at"
    ],
    "holistic_mentorship_phases" => [
      "frozen_at",
      "frozen_by_user_id",
      "grade_id",
      "guidance_markdown",
      "id",
      "inserted_at",
      "phase_plan_id",
      "position",
      "revision",
      "state",
      "title",
      "updated_at"
    ],
    "holistic_mentorship_phase_questions" => [
      "id",
      "inserted_at",
      "phase_id",
      "position",
      "text",
      "updated_at"
    ]
  }

  describe "Holistic Mentorship Phase Plan schema" do
    test "creates only the required Phase Plan tables and columns" do
      for {table, expected_columns} <- @expected_columns do
        assert column_names(table) == expected_columns
      end
    end

    test "uses restrictive canonical relationships, timestamps, and lookup indexes" do
      assert foreign_keys("holistic_mentorship_phase_plans") == [
               {"program_id", "program", "NO ACTION"}
             ]

      assert foreign_keys("holistic_mentorship_phases") == [
               {"frozen_by_user_id", "user", "NO ACTION"},
               {"grade_id", "grade", "NO ACTION"},
               {"phase_plan_id", "holistic_mentorship_phase_plans", "NO ACTION"}
             ]

      assert foreign_keys("holistic_mentorship_phase_questions") == [
               {"phase_id", "holistic_mentorship_phases", "NO ACTION"}
             ]

      for table <- Map.keys(@expected_columns) do
        assert_required(table, ["id", "inserted_at", "updated_at"])
      end

      assert_required("holistic_mentorship_phase_plans", ["program_id", "academic_year"])

      assert_required("holistic_mentorship_phases", [
        "phase_plan_id",
        "grade_id",
        "title",
        "position",
        "state",
        "guidance_markdown",
        "revision"
      ])

      assert_required("holistic_mentorship_phase_questions", ["phase_id", "text", "position"])

      assert index_names("holistic_mentorship_phase_plans") == [
               "hm_phase_plan_scope_unique",
               "hm_phase_plans_program_idx",
               "holistic_mentorship_phase_plans_pkey"
             ]

      assert index_names("holistic_mentorship_phases") == [
               "hm_phases_frozen_by_user_idx",
               "hm_phases_grade_idx",
               "hm_phases_plan_grade_state_position_idx",
               "hm_phases_plan_position_unique",
               "holistic_mentorship_phases_pkey"
             ]

      assert index_names("holistic_mentorship_phase_questions") == [
               "hm_phase_questions_phase_idx",
               "hm_phase_questions_phase_position_unique",
               "holistic_mentorship_phase_questions_pkey"
             ]
    end

    test "rejects invalid Phase and Question values" do
      %{plan_id: plan_id, grade_11_id: grade_11_id, grade_10_id: grade_10_id} = insert_scope()

      invalid_phases = [
        [plan_id, grade_10_id, "open", 1, 1],
        [plan_id, grade_11_id, "draft", 1, 1],
        [plan_id, grade_11_id, "open", 0, 1],
        [plan_id, grade_11_id, "open", 1, 0]
      ]

      for params <- invalid_phases do
        assert_constraint_violation(fn ->
          Repo.query(
            """
            INSERT INTO holistic_mentorship_phases
              (phase_plan_id, grade_id, title, position, state, guidance_markdown, revision)
            VALUES ($1, $2, 'Invalid phase', $4, $3, 'Guidance', $5)
            """,
            params
          )
        end)
      end

      phase_id = insert_phase(plan_id, grade_11_id, 1)

      Repo.query!(
        "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Question', 1)",
        [phase_id]
      )

      for position <- [0, 5] do
        assert_constraint_violation(fn ->
          Repo.query(
            """
            INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position)
            VALUES ($1, 'Invalid question', $2)
            """,
            [phase_id, position]
          )
        end)
      end

      assert_constraint_violation(fn ->
        Repo.query("UPDATE grade SET number = 10 WHERE id = $1", [grade_11_id])
      end)
    end

    test "enforces Plan-wide ordering and derives the latest Open Phase" do
      %{plan_id: plan_id, grade_11_id: grade_11_id, program_id: program_id} = insert_scope()

      assert_constraint_violation(fn ->
        Repo.query(
          """
          INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year)
          VALUES ($1, '2026-27')
          """,
          [program_id]
        )
      end)

      first_phase_id = insert_phase(plan_id, grade_11_id, 1)

      assert_constraint_violation(fn ->
        Repo.query(
          """
          INSERT INTO holistic_mentorship_phases
            (phase_plan_id, grade_id, title, position, state, guidance_markdown, revision)
          VALUES ($1, $2, 'Duplicate position', 1, 'locked', 'Guidance', 1)
          """,
          [plan_id, grade_11_id]
        )
      end)

      locked_phase_id = insert_phase(plan_id, grade_11_id, 2, "locked")
      active_phase_id = insert_phase(plan_id, grade_11_id, 3)

      Repo.query!(
        """
        INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position)
        VALUES ($1, 'First?', 1), ($2, 'Second?', 1), ($3, 'Third?', 1)
        """,
        [first_phase_id, locked_phase_id, active_phase_id]
      )

      assert Repo.query!(
               """
               SELECT id
               FROM holistic_mentorship_phases
               WHERE phase_plan_id = $1 AND grade_id = $2 AND state = 'open'
               ORDER BY position DESC
               LIMIT 1
               """,
               [plan_id, grade_11_id]
             ).rows == [[active_phase_id]]
    end

    test "defers Question cardinality until commit" do
      {empty_result, complete_result, overfull_result, moved_result} =
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          canonical = insert_committed_canonical_scope()

          try do
            {
              commit_phase(canonical, "cardinality-empty", 0),
              commit_phase(canonical, "cardinality-complete", 1),
              commit_phase(canonical, "cardinality-overfull", 5),
              move_only_question(canonical)
            }
          after
            delete_committed_canonical_scope(canonical)
          end
        end)

      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = empty_result
      assert {:ok, _phase_id} = complete_result
      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = overfull_result
      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = moved_result
    end

    test "restricts deletion of Phase definitions in use" do
      %{plan_id: plan_id, grade_11_id: grade_11_id} = insert_scope()
      phase_id = insert_phase(plan_id, grade_11_id, 1)

      Repo.query!(
        "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Question', 1)",
        [phase_id]
      )

      assert_constraint_violation(fn ->
        Repo.query("DELETE FROM holistic_mentorship_phases WHERE id = $1", [phase_id])
      end)

      assert_constraint_violation(fn ->
        Repo.query("DELETE FROM holistic_mentorship_phase_plans WHERE id = $1", [plan_id])
      end)
    end
  end

  defp column_names(table) do
    Repo.query!(
      """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      ORDER BY column_name
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp assert_required(table, expected) do
    nullable =
      Repo.query!(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = $1 AND is_nullable = 'YES'
        """,
        [table]
      ).rows
      |> Enum.map(fn [name] -> name end)

    for column <- expected do
      refute column in nullable, "#{table}.#{column} should be NOT NULL"
    end
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

  defp index_names(table) do
    Repo.query!(
      """
      SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = $1
      ORDER BY indexname
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp insert_scope do
    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM test', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM test', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[grade_11_id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES (11, now(), now()) RETURNING id"
      ).rows

    [[grade_10_id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES (10, now(), now()) RETURNING id"
      ).rows

    [[plan_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year)
        VALUES ($1, '2026-27')
        RETURNING id
        """,
        [program_id]
      ).rows

    %{
      plan_id: plan_id,
      program_id: program_id,
      grade_11_id: grade_11_id,
      grade_10_id: grade_10_id
    }
  end

  defp insert_phase(plan_id, grade_id, position, state \\ "open") do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_phases
          (phase_plan_id, grade_id, title, position, state, guidance_markdown, revision)
        VALUES ($1, $2, 'Check-in', $3, $4, '## Guidance', 1)
        RETURNING id
        """,
        [plan_id, grade_id, position, state]
      ).rows

    id
  end

  defp assert_constraint_violation(query) do
    {:error, result} =
      Repo.transaction(
        fn -> Repo.rollback(query.()) end,
        mode: :savepoint
      )

    assert {:error, %Postgrex.Error{postgres: %{code: code}}} = result
    assert code in [:check_violation, :foreign_key_violation, :raise_exception, :unique_violation]
  end

  defp insert_committed_canonical_scope do
    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HM cardinality', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HM cardinality', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[grade_id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES (11, now(), now()) RETURNING id"
      ).rows

    %{product_id: product_id, program_id: program_id, grade_id: grade_id}
  end

  defp commit_phase(scope, academic_year, question_count) do
    Repo.transaction(fn ->
      [[plan_id]] =
        Repo.query!(
          "INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year) VALUES ($1, $2) RETURNING id",
          [scope.program_id, academic_year]
        ).rows

      phase_id = insert_phase(plan_id, scope.grade_id, 1)

      for position <- 1..question_count//1 do
        Repo.query!(
          "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Question', $2)",
          [phase_id, position]
        )
      end

      phase_id
    end)
  rescue
    error in Postgrex.Error -> {:error, error}
  end

  defp move_only_question(scope) do
    {:ok, {question_id, target_phase_id}} =
      Repo.transaction(fn ->
        [[plan_id]] =
          Repo.query!(
            "INSERT INTO holistic_mentorship_phase_plans (program_id, academic_year) VALUES ($1, 'cardinality-move') RETURNING id",
            [scope.program_id]
          ).rows

        source_phase_id = insert_phase(plan_id, scope.grade_id, 1)
        target_phase_id = insert_phase(plan_id, scope.grade_id, 2)

        [[question_id]] =
          Repo.query!(
            "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Source', 1) RETURNING id",
            [source_phase_id]
          ).rows

        Repo.query!(
          "INSERT INTO holistic_mentorship_phase_questions (phase_id, text, position) VALUES ($1, 'Target', 1)",
          [target_phase_id]
        )

        {question_id, target_phase_id}
      end)

    Repo.transaction(fn ->
      Repo.query!(
        "UPDATE holistic_mentorship_phase_questions SET phase_id = $1, position = 2 WHERE id = $2",
        [target_phase_id, question_id]
      )
    end)
  rescue
    error in Postgrex.Error -> {:error, error}
  end

  defp delete_committed_canonical_scope(scope) do
    Repo.transaction(fn ->
      Repo.query!(
        "DELETE FROM holistic_mentorship_phase_questions WHERE phase_id IN (SELECT id FROM holistic_mentorship_phases WHERE phase_plan_id IN (SELECT id FROM holistic_mentorship_phase_plans WHERE program_id = $1))",
        [scope.program_id]
      )

      Repo.query!(
        "DELETE FROM holistic_mentorship_phases WHERE phase_plan_id IN (SELECT id FROM holistic_mentorship_phase_plans WHERE program_id = $1)",
        [scope.program_id]
      )

      Repo.query!("DELETE FROM holistic_mentorship_phase_plans WHERE program_id = $1", [
        scope.program_id
      ])

      Repo.query!("DELETE FROM grade WHERE id = $1", [scope.grade_id])
      Repo.query!("DELETE FROM program WHERE id = $1", [scope.program_id])
      Repo.query!("DELETE FROM product WHERE id = $1", [scope.product_id])
    end)
  end
end
