defmodule Dbservice.BlendedLearningActionItemsSchemaTest do
  use Dbservice.DataCase, async: false

  @action_items "blended_learning_action_items"
  @conversations "blended_learning_conversations"

  test "rejects a Student that does not own the creating or closing Conversation" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})

    {:ok, %{rows: [[other_conversation_id]]}} =
      insert_conversation(%{scope | student_id: scope.other_student_id}, %{})

    {:ok, %{rows: [[item_id]]}} = insert_action_item(scope, conversation_id, %{position: 1})

    assert_constraint(:foreign_key_violation, fn ->
      insert_action_item(%{scope | student_id: scope.other_student_id}, conversation_id, %{
        position: 2
      })
    end)

    assert_constraint(:foreign_key_violation, fn ->
      Repo.query(
        """
        UPDATE #{@action_items}
        SET status = 'done', completed_by_conversation_id = $2,
            completed_at = '2026-10-27 11:00:00', completed_by_email = 'mentor@example.org'
        WHERE id = $1
        """,
        [item_id, other_conversation_id]
      )
    end)

    assert Repo.query!("SELECT status FROM #{@action_items} WHERE id = $1", [item_id]).rows ==
             [["open"]]
  end

  test "requires the completion fields exactly when an Action Item is done" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[closing_id]]}} = insert_conversation(scope, %{occurred_on: ~D[2026-10-21]})

    completion = %{
      completed_by_conversation_id: closing_id,
      completed_at: ~N[2026-10-21 09:30:00],
      completed_by_email: "mentor@example.org"
    }

    assert {:ok, _} = insert_action_item(scope, conversation_id, %{position: 1})

    assert {:ok, _} =
             insert_action_item(
               scope,
               conversation_id,
               Map.merge(completion, %{position: 2, status: "done"})
             )

    assert_constraint(:check_violation, fn ->
      insert_action_item(scope, conversation_id, %{position: 3, status: "done"})
    end)

    for {field, value} <- completion do
      assert_constraint(:check_violation, fn ->
        insert_action_item(
          scope,
          conversation_id,
          %{position: 3, status: "done"} |> Map.merge(completion) |> Map.put(field, nil)
        )
      end)

      assert_constraint(:check_violation, fn ->
        insert_action_item(scope, conversation_id, %{field => value, position: 3})
      end)
    end
  end

  test "numbers Action Items from 1, uniquely within a Conversation" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[other_conversation_id]]}} = insert_conversation(scope, %{})

    assert {:ok, _} = insert_action_item(scope, conversation_id, %{position: 1})
    assert {:ok, _} = insert_action_item(scope, other_conversation_id, %{position: 1})

    assert_constraint(:unique_violation, fn ->
      insert_action_item(scope, conversation_id, %{position: 1})
    end)

    assert_constraint(:check_violation, fn ->
      insert_action_item(scope, conversation_id, %{position: 0})
    end)
  end

  test "accepts each owner and rejects blank text, an unknown owner or status and a blank completer email" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[closing_id]]}} = insert_conversation(scope, %{occurred_on: ~D[2026-10-21]})

    completion = %{
      completed_by_conversation_id: closing_id,
      completed_at: ~N[2026-10-21 09:30:00],
      completed_by_email: "mentor@example.org"
    }

    for {owner, position} <- [{"student", 1}, {"mentor", 2}, {"parent", 3}] do
      assert {:ok, _} =
               insert_action_item(scope, conversation_id, %{owner: owner, position: position})
    end

    for attrs <- [
          %{text: ""},
          %{text: " \n\t"},
          %{owner: "sibling"},
          Map.put(completion, :status, "cancelled"),
          completion |> Map.put(:status, "done") |> Map.put(:completed_by_email, "  ")
        ] do
      assert_constraint(:check_violation, fn ->
        insert_action_item(scope, conversation_id, Map.put(attrs, :position, 4))
      end)
    end
  end

  test "closes an open Action Item by linking the later Conversation" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[closing_id]]}} = insert_conversation(scope, %{occurred_on: ~D[2026-10-27]})

    {:ok, %{rows: [[item_id]]}} =
      insert_action_item(scope, conversation_id, %{owner: "parent"})

    assert %{num_rows: 1} =
             Repo.query!(
               """
               UPDATE #{@action_items}
               SET status = 'done', completed_by_conversation_id = $2,
                   completed_at = '2026-10-27 11:00:00', completed_by_email = 'mentor@example.org',
                   updated_at = '2026-10-27 11:00:00'
               WHERE id = $1
               """,
               [item_id, closing_id]
             )

    assert Repo.query!(
             """
             SELECT conversation_id, student_id, position, text, owner, status,
                    completed_by_conversation_id, completed_at, completed_by_email
             FROM #{@action_items} WHERE id = $1
             """,
             [item_id]
           ).rows == [
             [
               conversation_id,
               scope.student_id,
               1,
               "Finish the chapter 3 worksheet.",
               "parent",
               "done",
               closing_id,
               ~N[2026-10-27 11:00:00],
               "mentor@example.org"
             ]
           ]
  end

  defp insert_scope do
    [[student_user_id], [other_student_user_id], [mentor_user_id]] =
      Repo.query!("""
      INSERT INTO "user" (inserted_at, updated_at)
      VALUES (now(), now()), (now(), now()), (now(), now())
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Action Items', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Action Items', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_conversation(scope, attrs) do
    insert_row(
      @conversations,
      Map.merge(
        %{
          student_id: scope.student_id,
          program_id: scope.program_id,
          mentor_user_id: scope.mentor_user_id,
          kind: "conversation",
          academic_year: "2026-2027",
          logged_by_email: "ops@example.org",
          occurred_on: ~D[2026-10-20],
          mode: "call",
          spoke_with: "student",
          duration_minutes: 25,
          summary: "Discussed the mock test plan."
        },
        attrs
      )
    )
  end

  defp insert_action_item(scope, conversation_id, attrs) do
    insert_row(
      @action_items,
      Map.merge(
        %{
          conversation_id: conversation_id,
          student_id: scope.student_id,
          position: 1,
          text: "Finish the chapter 3 worksheet.",
          owner: "student"
        },
        attrs
      )
    )
  end

  defp insert_row(table, attrs) do
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
