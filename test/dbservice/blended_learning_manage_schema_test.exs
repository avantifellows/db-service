defmodule Dbservice.BlendedLearningManageSchemaTest do
  use Dbservice.DataCase, async: false

  @resources "blended_learning_resources"
  @common "blended_learning_common_action_items"
  @action_items "blended_learning_action_items"
  @conversations "blended_learning_conversations"

  describe "Resources" do
    test "seeds the Mentor Toolkit doc as the first resource" do
      assert Repo.query!("""
             SELECT title, url, position, created_by_email, updated_by_email
             FROM #{@resources}
             ORDER BY position, id
             """).rows == [
               [
                 "Mentor Toolkit: Supporting Students Through Non-Academic Stress",
                 "https://docs.google.com/document/d/1kST-wRFTWgczw7SqBAxW97KNyJ0fzuBoOBsIelTQ8W0/edit?usp=sharing",
                 1,
                 nil,
                 nil
               ]
             ]
    end

    test "stores a titled https link at a position from 1, and deletes it" do
      assert {:ok, %{rows: [[id]]}} = insert_resource(%{})

      Repo.query!(
        "UPDATE #{@resources} SET title = $2, position = 3, updated_by_email = $3 WHERE id = $1",
        [id, "Exam stress guide", "admin@example.org"]
      )

      assert Repo.query!(
               "SELECT title, url, position, created_by_email, updated_by_email FROM #{@resources} WHERE id = $1",
               [id]
             ).rows == [
               [
                 "Exam stress guide",
                 "https://example.org/guide",
                 3,
                 "admin@example.org",
                 "admin@example.org"
               ]
             ]

      assert %{num_rows: 1} = Repo.query!("DELETE FROM #{@resources} WHERE id = $1", [id])
    end

    test "rejects a blank or long title, a non-https URL, position 0 and blank emails" do
      for attrs <- [
            %{title: ""},
            %{title: " \n\t"},
            %{url: "http://example.org/guide"},
            %{url: "https://example.org/a guide"},
            %{url: "https://"},
            %{url: "example.org/guide"},
            %{position: 0},
            %{created_by_email: "  "},
            %{updated_by_email: ""}
          ] do
        assert_constraint(:check_violation, fn -> insert_resource(attrs) end)
      end

      assert_constraint(:string_data_right_truncation, fn ->
        insert_resource(%{title: String.duplicate("a", 201)})
      end)

      assert {:ok, _} = insert_resource(%{title: String.duplicate("a", 200)})
    end
  end

  describe "Common Action Items" do
    test "accepts each target with its own field only" do
      scope = insert_scope()

      for attrs <- [
            %{target_kind: "all"},
            %{target_kind: "grade", target_grade: 12},
            %{target_kind: "grade", target_grade: 13},
            %{target_kind: "mentor", target_mentor_user_id: scope.mentor_user_id},
            %{target_kind: "students", target_student_ids: ["01234567890"]},
            %{target_kind: "students", target_student_ids: ["12345678", "0098765432"]}
          ] do
        assert {:ok, _} = insert_common(attrs)
      end

      # Student IDs keep their leading zeros.
      assert Repo.query!(
               "SELECT target_student_ids FROM #{@common} WHERE target_kind = 'students' ORDER BY id"
             ).rows == [[["01234567890"]], [["12345678", "0098765432"]]]

      for attrs <- [
            %{target_kind: "everyone"},
            %{target_kind: "all", target_grade: 12},
            %{target_kind: "all", target_mentor_user_id: scope.mentor_user_id},
            %{target_kind: "grade"},
            %{target_kind: "grade", target_grade: 11},
            %{
              target_kind: "grade",
              target_grade: 12,
              target_mentor_user_id: scope.mentor_user_id
            },
            %{target_kind: "mentor"},
            %{
              target_kind: "mentor",
              target_mentor_user_id: scope.mentor_user_id,
              target_grade: 12
            },
            %{target_kind: "all", target_student_ids: ["12345678"]},
            %{target_kind: "grade", target_grade: 12, target_student_ids: ["12345678"]},
            %{
              target_kind: "mentor",
              target_mentor_user_id: scope.mentor_user_id,
              target_student_ids: ["12345678"]
            },
            %{target_kind: "students"},
            %{target_kind: "students", target_student_ids: []},
            %{target_kind: "students", target_student_ids: ["12345678", nil]},
            %{target_kind: "students", target_student_ids: ["12345678"], target_grade: 12},
            %{
              target_kind: "students",
              target_student_ids: ["12345678"],
              target_mentor_user_id: scope.mentor_user_id
            }
          ] do
        assert_constraint(:check_violation, fn -> insert_common(attrs) end)
      end

      assert_constraint(:foreign_key_violation, fn ->
        insert_common(%{target_kind: "mentor", target_mentor_user_id: -1})
      end)
    end

    test "rejects blank or over-long text, an unknown owner and a blank creator" do
      for owner <- ["student", "mentor", "parent"] do
        assert {:ok, _} = insert_common(%{owner: owner})
      end

      assert {:ok, _} = insert_common(%{text: String.duplicate("a", 500)})

      for attrs <- [
            %{text: ""},
            %{text: " \n\t"},
            %{text: String.duplicate("a", 501)},
            %{owner: "sibling"},
            %{created_by_email: " "}
          ] do
        assert_constraint(:check_violation, fn -> insert_common(attrs) end)
      end
    end

    test "is removed only with both the time and the remover" do
      {:ok, %{rows: [[id]]}} = insert_common(%{})

      for {sql, params} <- [
            {"removed_at = now()", []},
            {"removed_by_email = $2", ["admin@example.org"]},
            {"removed_at = now(), removed_by_email = $2", [" "]}
          ] do
        assert_constraint(:check_violation, fn ->
          Repo.query("UPDATE #{@common} SET #{sql} WHERE id = $1", [id | params])
        end)
      end

      assert %{num_rows: 1} =
               Repo.query!(
                 "UPDATE #{@common} SET removed_at = now(), removed_by_email = $2 WHERE id = $1",
                 [id, "admin@example.org"]
               )
    end
  end

  describe "Action Items from a Common Action Item" do
    test "belong to exactly one Conversation or one Common Action Item" do
      scope = insert_scope()
      {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
      {:ok, %{rows: [[common_id]]}} = insert_common(%{})

      assert {:ok, _} = insert_action_item(scope, %{conversation_id: conversation_id})
      assert {:ok, _} = insert_action_item(scope, %{common_action_item_id: common_id})

      assert_constraint(:check_violation, fn -> insert_action_item(scope, %{}) end)

      assert_constraint(:check_violation, fn ->
        insert_action_item(scope, %{
          conversation_id: conversation_id,
          common_action_item_id: common_id,
          position: 2
        })
      end)

      assert_constraint(:foreign_key_violation, fn ->
        insert_action_item(scope, %{common_action_item_id: -1})
      end)
    end

    test "reach a Student at most once per Common Action Item" do
      scope = insert_scope()
      {:ok, %{rows: [[common_id]]}} = insert_common(%{})
      {:ok, %{rows: [[other_common_id]]}} = insert_common(%{})

      assert {:ok, _} = insert_action_item(scope, %{common_action_item_id: common_id})
      assert {:ok, _} = insert_action_item(scope, %{common_action_item_id: other_common_id})

      assert {:ok, _} =
               insert_action_item(%{scope | student_id: scope.other_student_id}, %{
                 common_action_item_id: common_id
               })

      assert_constraint(:unique_violation, fn ->
        insert_action_item(scope, %{common_action_item_id: common_id})
      end)

      assert %{num_rows: 0} =
               Repo.query!(
                 """
                 INSERT INTO #{@action_items} (common_action_item_id, student_id, position, text, owner)
                 VALUES ($1, $2, 1, 'Pushed again.', 'student')
                 ON CONFLICT (common_action_item_id, student_id)
                   WHERE common_action_item_id IS NOT NULL DO NOTHING
                 """,
                 [common_id, scope.student_id]
               )
    end

    test "are closed by a later Conversation of the same Student, like any Action Item" do
      scope = insert_scope()
      {:ok, %{rows: [[common_id]]}} = insert_common(%{})
      {:ok, %{rows: [[closing_id]]}} = insert_conversation(scope, %{})

      {:ok, %{rows: [[other_closing_id]]}} =
        insert_conversation(%{scope | student_id: scope.other_student_id}, %{})

      {:ok, %{rows: [[item_id]]}} =
        insert_action_item(scope, %{common_action_item_id: common_id})

      close = fn conversation_id ->
        Repo.query(
          """
          UPDATE #{@action_items}
          SET status = 'done', completed_by_conversation_id = $2,
              completed_at = '2026-10-27 11:00:00', completed_by_email = 'mentor@example.org'
          WHERE id = $1
          """,
          [item_id, conversation_id]
        )
      end

      assert_constraint(:foreign_key_violation, fn -> close.(other_closing_id) end)
      assert {:ok, %{num_rows: 1}} = close.(closing_id)

      assert Repo.query!(
               """
               SELECT conversation_id, common_action_item_id, status, completed_by_conversation_id
               FROM #{@action_items} WHERE id = $1
               """,
               [item_id]
             ).rows == [[nil, common_id, "done", closing_id]]
    end
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Manage', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Manage', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_resource(attrs) do
    insert_row(
      @resources,
      Map.merge(
        %{
          title: "Study plan template",
          url: "https://example.org/guide",
          position: 2,
          created_by_email: "admin@example.org",
          updated_by_email: "admin@example.org"
        },
        attrs
      )
    )
  end

  defp insert_common(attrs) do
    insert_row(
      @common,
      Map.merge(
        %{
          text: "Fill in the scholarship form.",
          owner: "student",
          target_kind: "all",
          created_by_email: "admin@example.org"
        },
        attrs
      )
    )
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

  defp insert_action_item(scope, attrs) do
    insert_row(
      @action_items,
      Map.merge(
        %{
          student_id: scope.student_id,
          position: 1,
          text: "Fill in the scholarship form.",
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
