defmodule Dbservice.BlendedLearningScreenerFeedbackSchemaTest do
  use Dbservice.DataCase, async: false

  @conversations "blended_learning_conversations"
  @feedback "blended_learning_screener_feedback"

  @conversation %{
    kind: "conversation",
    academic_year: "2026-2027",
    logged_by_email: "ops@example.org",
    occurred_on: ~D[2026-10-27],
    mode: "call",
    spoke_with: "student",
    duration_minutes: 20,
    summary: "Went through the screener answers."
  }

  @attempt %{
    kind: "attempt",
    academic_year: "2026-2027",
    logged_by_email: "ops@example.org",
    occurred_on: ~D[2026-10-26]
  }

  describe "screener_used on Conversations" do
    test "is true, false or NULL on a Conversation and only NULL on an Attempt" do
      scope = insert_scope()

      for used <- [true, false, nil] do
        assert {:ok, %{rows: [[id]]}} = insert_conversation(scope, %{screener_used: used})

        assert Repo.query!("SELECT screener_used FROM #{@conversations} WHERE id = $1", [id]).rows ==
                 [[used]]
      end

      assert {:ok, _} = insert_attempt(scope, %{screener_used: nil})
      assert {:ok, %{rows: [[attempt_id]]}} = insert_attempt(scope, %{})

      assert Repo.query!("SELECT screener_used FROM #{@conversations} WHERE id = $1", [attempt_id]).rows ==
               [[nil]]

      for used <- [true, false] do
        assert_constraint(:check_violation, fn ->
          insert_attempt(scope, %{screener_used: used})
        end)
      end
    end

    test "can't be changed after the Conversation is saved" do
      scope = insert_scope()
      {:ok, %{rows: [[id]]}} = insert_conversation(scope, %{screener_used: false})

      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@conversations} SET screener_used = true WHERE id = $1", [id])
      end)
    end
  end

  describe "Screener feedback" do
    test "stores two ratings from 1 to 5 against the Conversation that gave them" do
      scope = insert_scope()
      {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{screener_used: true})

      assert {:ok, %{rows: [[id]]}} =
               insert_feedback(scope, conversation_id, %{
                 helped_understand: 1,
                 more_comfortable: 5
               })

      assert Repo.query!(
               """
               SELECT student_id, conversation_id, mentor_user_id, helped_understand, more_comfortable,
                      inserted_at IS NOT NULL
               FROM #{@feedback} WHERE id = $1
               """,
               [id]
             ).rows == [[scope.student_id, conversation_id, scope.mentor_user_id, 1, 5, true]]
    end

    test "rejects a missing or out-of-range rating" do
      scope = insert_scope()
      {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{screener_used: true})

      for attrs <- [
            %{helped_understand: 0},
            %{helped_understand: 6},
            %{more_comfortable: 0},
            %{more_comfortable: -1},
            %{more_comfortable: 6}
          ] do
        assert_constraint(:check_violation, fn ->
          insert_feedback(scope, conversation_id, attrs)
        end)
      end

      for attrs <- [%{helped_understand: nil}, %{more_comfortable: nil}, %{mentor_user_id: nil}] do
        assert_constraint(:not_null_violation, fn ->
          insert_feedback(scope, conversation_id, attrs)
        end)
      end
    end

    test "allows one feedback per Student, whichever Conversation or Mentor gives it" do
      scope = insert_scope()
      {:ok, %{rows: [[first_id]]}} = insert_conversation(scope, %{screener_used: true})
      {:ok, %{rows: [[second_id]]}} = insert_conversation(scope, %{screener_used: true})

      assert {:ok, _} = insert_feedback(scope, first_id, %{})

      assert_constraint(:unique_violation, fn -> insert_feedback(scope, first_id, %{}) end)

      assert_constraint(:unique_violation, fn ->
        insert_feedback(scope, second_id, %{mentor_user_id: scope.other_mentor_user_id})
      end)

      other_scope = %{scope | student_id: scope.other_student_id}
      {:ok, %{rows: [[other_id]]}} = insert_conversation(other_scope, %{screener_used: true})
      assert {:ok, _} = insert_feedback(other_scope, other_id, %{})
    end

    test "must point at a Conversation of the same Student" do
      scope = insert_scope()
      other_scope = %{scope | student_id: scope.other_student_id}
      {:ok, %{rows: [[other_conversation_id]]}} = insert_conversation(other_scope, %{})

      assert_constraint(:foreign_key_violation, fn ->
        insert_feedback(scope, other_conversation_id, %{})
      end)

      assert_constraint(:foreign_key_violation, fn -> insert_feedback(scope, -1, %{}) end)
    end
  end

  defp insert_scope do
    [[student_user_id], [other_student_user_id], [mentor_user_id], [other_mentor_user_id]] =
      Repo.query!("""
      INSERT INTO "user" (inserted_at, updated_at)
      VALUES (now(), now()), (now(), now()), (now(), now()), (now(), now())
      RETURNING id
      """).rows

    [[student_id], [other_student_id]] =
      Repo.query!(
        """
        INSERT INTO student (user_id, inserted_at, updated_at)
        VALUES ($1, now(), now()), ($2, now(), now())
        RETURNING id
        """,
        [student_user_id, other_student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Screener', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Screener', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_mentor_user_id: other_mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_conversation(scope, attrs),
    do: insert_entry(scope, Map.merge(@conversation, attrs))

  defp insert_attempt(scope, attrs), do: insert_entry(scope, Map.merge(@attempt, attrs))

  defp insert_entry(scope, attrs) do
    %{student_id: scope.student_id, program_id: scope.program_id}
    |> Map.put(:mentor_user_id, scope.mentor_user_id)
    |> Map.merge(attrs)
    |> insert_row(@conversations)
  end

  defp insert_feedback(scope, conversation_id, attrs) do
    %{
      student_id: scope.student_id,
      conversation_id: conversation_id,
      mentor_user_id: scope.mentor_user_id,
      helped_understand: 4,
      more_comfortable: 3
    }
    |> Map.merge(attrs)
    |> insert_row(@feedback)
  end

  defp insert_row(attrs, table) do
    {columns, values} = attrs |> Enum.sort() |> Enum.unzip()
    placeholders = Enum.map_join(1..length(values), ", ", &"$#{&1}")

    Repo.query(
      "INSERT INTO #{table} (#{Enum.join(columns, ", ")}) VALUES (#{placeholders}) RETURNING id",
      values
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
