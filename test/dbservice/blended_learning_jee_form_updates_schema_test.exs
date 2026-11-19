defmodule Dbservice.BlendedLearningJeeFormUpdatesSchemaTest do
  use Dbservice.DataCase, async: false

  @updates "blended_learning_jee_form_updates"
  @flags "blended_learning_mentor_flags"
  @action_items "blended_learning_action_items"
  @conversations "blended_learning_conversations"

  @reasons ~w(
    certificate_not_available
    document_issue
    form_difficulty
    awaiting_parent_salary
    personal_issues
    not_interested
    not_prepared
    phase_two
    not_sharing_details
    not_aware
    other
  )

  describe "JEE form updates" do
    test "stores a filled update with its application number and optional confirmation" do
      scope = insert_scope()
      document_id = insert_document(scope)

      assert {:ok, %{rows: [[without_pdf]]}} = insert_filled(scope, %{})

      assert {:ok, %{rows: [[with_pdf]]}} =
               insert_filled(scope, %{confirmation_document_id: document_id})

      assert Repo.query!(
               """
               SELECT id, status, application_number, confirmation_document_id, reasons, details,
                      exam_year, inserted_at IS NOT NULL
               FROM #{@updates} WHERE student_id = $1 ORDER BY id
               """,
               [scope.student_id]
             ).rows == [
               [without_pdf, "filled", "270310000001", nil, nil, nil, 2027, true],
               [with_pdf, "filled", "270310000001", document_id, nil, nil, 2027, true]
             ]
    end

    test "has no password column" do
      columns =
        Repo.query!(
          "SELECT column_name FROM information_schema.columns WHERE table_name = $1",
          [@updates]
        ).rows
        |> List.flatten()

      refute Enum.any?(columns, &String.contains?(&1, "password"))
    end

    test "a filled update needs an application number and takes no reasons or details" do
      scope = insert_scope()

      for attrs <- [
            %{application_number: ""},
            %{application_number: "   "},
            %{reasons: ["not_aware"]},
            %{details: "Filled at the cyber cafe."}
          ] do
        assert_constraint(:check_violation, fn -> insert_filled(scope, attrs) end)
      end

      assert_constraint(:check_violation, fn ->
        insert_filled(scope, %{application_number: nil})
      end)
    end

    test "a not-filled update takes every listed reason, and 'other' needs details" do
      scope = insert_scope()

      assert {:ok, _} =
               insert_not_filled(scope, %{reasons: @reasons, details: "Waiting on a form."})

      assert {:ok, _} = insert_not_filled(scope, %{reasons: ["not_aware"], details: nil})
      assert {:ok, _} = insert_not_filled(scope, %{reasons: ["other"], details: "Moved house."})

      for attrs <- [
            %{reasons: nil},
            %{reasons: []},
            %{reasons: ["not_aware", nil]},
            %{reasons: ["Not aware about the exam"]},
            %{reasons: ["biology"]},
            %{reasons: ["other"], details: nil},
            %{reasons: ["not_aware", "other"], details: nil},
            %{details: ""},
            %{details: " \n"},
            %{details: String.duplicate("a", 2001)},
            %{application_number: "270310000001"}
          ] do
        assert_constraint(:check_violation, fn -> insert_not_filled(scope, attrs) end)
      end

      document_id = insert_document(scope)

      assert_constraint(:check_violation, fn ->
        insert_not_filled(scope, %{confirmation_document_id: document_id})
      end)
    end

    test "rejects an unknown status, an implausible year or a blank recorder" do
      scope = insert_scope()

      for attrs <- [
            %{status: "submitted"},
            %{exam_year: 27},
            %{recorded_by_email: " "},
            %{academic_year: ""}
          ] do
        assert_constraint(:check_violation, fn -> insert_filled(scope, attrs) end)
      end
    end

    test "is append-only" do
      scope = insert_scope()
      {:ok, %{rows: [[id]]}} = insert_filled(scope, %{})

      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@updates} SET application_number = 'x' WHERE id = $1", [id])
      end)

      assert_constraint(:check_violation, fn ->
        Repo.query("DELETE FROM #{@updates} WHERE id = $1", [id])
      end)
    end
  end

  describe "JEE form flags" do
    test "a not-filled update raises one 'jee_form' flag with no Conversation" do
      scope = insert_scope()
      {:ok, %{rows: [[update_id]]}} = insert_not_filled(scope, %{})

      assert {:ok, _} =
               insert_flag(scope, %{jee_form_update_id: update_id, recipient: "jee_form"})

      assert_constraint(:unique_violation, fn ->
        insert_flag(scope, %{jee_form_update_id: update_id, recipient: "jee_form"})
      end)
    end

    test "a flag comes from exactly one source, and only the JEE form raises 'jee_form'" do
      scope = insert_scope()
      {:ok, %{rows: [[update_id]]}} = insert_not_filled(scope, %{})
      {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope)

      assert {:ok, _} =
               insert_flag(scope, %{conversation_id: conversation_id, recipient: "physics"})

      for attrs <- [
            %{recipient: "jee_form"},
            %{conversation_id: conversation_id, recipient: "jee_form"},
            %{jee_form_update_id: update_id, recipient: "physics"},
            %{
              conversation_id: conversation_id,
              jee_form_update_id: update_id,
              recipient: "jee_form"
            }
          ] do
        assert_constraint(:check_violation, fn -> insert_flag(scope, attrs) end)
      end
    end

    test "must point at an update of the same Student" do
      scope = insert_scope()
      other_scope = %{scope | student_id: scope.other_student_id}
      {:ok, %{rows: [[other_update_id]]}} = insert_not_filled(other_scope, %{})

      assert_constraint(:foreign_key_violation, fn ->
        insert_flag(scope, %{jee_form_update_id: other_update_id, recipient: "jee_form"})
      end)
    end
  end

  describe "Action Items ticked by a JEE form" do
    test "a done item is completed by a Conversation or a JEE form update, never both or neither" do
      scope = insert_scope()
      {:ok, %{rows: [[update_id]]}} = insert_filled(scope, %{})
      {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope)
      {:ok, %{rows: [[common_id]]}} = insert_common()

      done = %{
        status: "done",
        completed_at: ~U[2026-11-10 06:00:00Z],
        completed_by_email: "mentor@example.org"
      }

      assert {:ok, _} =
               insert_action_item(
                 scope,
                 Map.merge(done, %{
                   common_action_item_id: common_id,
                   completed_by_jee_form_update_id: update_id
                 })
               )

      assert {:ok, _} =
               insert_action_item(
                 scope,
                 Map.merge(done, %{
                   conversation_id: conversation_id,
                   completed_by_conversation_id: conversation_id
                 })
               )

      for attrs <- [
            Map.merge(done, %{
              completed_by_conversation_id: conversation_id,
              completed_by_jee_form_update_id: update_id
            }),
            done,
            %{completed_by_jee_form_update_id: update_id}
          ] do
        assert_constraint(:check_violation, fn ->
          insert_action_item(scope, Map.put(attrs, :conversation_id, conversation_id))
        end)
      end
    end

    test "must point at an update of the same Student" do
      scope = insert_scope()
      other_scope = %{scope | student_id: scope.other_student_id}
      {:ok, %{rows: [[other_update_id]]}} = insert_filled(other_scope, %{})
      {:ok, %{rows: [[common_id]]}} = insert_common()

      assert_constraint(:foreign_key_violation, fn ->
        insert_action_item(scope, %{
          common_action_item_id: common_id,
          status: "done",
          completed_at: ~U[2026-11-10 06:00:00Z],
          completed_by_email: "mentor@example.org",
          completed_by_jee_form_update_id: other_update_id
        })
      end)
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL JEE', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL JEE', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[exam_id]] =
      Repo.query!(
        "INSERT INTO exam (name, inserted_at, updated_at) VALUES ('JEE Mains', now(), now()) RETURNING id"
      ).rows

    %{
      exam_id: exam_id,
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_document(scope) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO lms_student_documents (student_id, document_type, pages, metadata, uploaded_by)
        VALUES ($1, 'jee_main_confirmation', '[]'::jsonb, '{}'::jsonb, 'mentor@example.org')
        RETURNING id
        """,
        [scope.student_id]
      ).rows

    id
  end

  defp insert_filled(scope, attrs),
    do:
      insert_update(
        scope,
        Map.merge(%{status: "filled", application_number: "270310000001"}, attrs)
      )

  defp insert_not_filled(scope, attrs),
    do:
      insert_update(
        scope,
        Map.merge(%{status: "not_filled", reasons: ["certificate_not_available"]}, attrs)
      )

  defp insert_update(scope, attrs) do
    insert_row(
      @updates,
      Map.merge(
        %{
          student_id: scope.student_id,
          exam_id: scope.exam_id,
          exam_year: 2027,
          mentor_user_id: scope.mentor_user_id,
          program_id: scope.program_id,
          academic_year: "2026-2027",
          recorded_by_email: "mentor@example.org"
        },
        attrs
      )
    )
  end

  defp insert_conversation(scope) do
    insert_row(@conversations, %{
      student_id: scope.student_id,
      program_id: scope.program_id,
      mentor_user_id: scope.mentor_user_id,
      kind: "conversation",
      academic_year: "2026-2027",
      logged_by_email: "mentor@example.org",
      occurred_on: ~D[2026-11-09],
      mode: "call",
      spoke_with: "student",
      duration_minutes: 20,
      summary: "Talked about the JEE form."
    })
  end

  defp insert_flag(scope, attrs) do
    insert_row(
      @flags,
      Map.merge(
        %{
          student_id: scope.student_id,
          comment: "Not filled: Not aware about the exam",
          raised_by_email: "mentor@example.org"
        },
        attrs
      )
    )
  end

  defp insert_common do
    insert_row("blended_learning_common_action_items", %{
      text: "JEE Form Filling (Reminder)",
      owner: "student",
      target_kind: "all",
      created_by_email: "admin@example.org"
    })
  end

  defp insert_action_item(scope, attrs) do
    insert_row(
      @action_items,
      Map.merge(
        %{
          student_id: scope.student_id,
          position: 1,
          text: "JEE Form Filling (Reminder)",
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
