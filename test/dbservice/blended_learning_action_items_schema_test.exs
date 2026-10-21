defmodule Dbservice.BlendedLearningActionItemsSchemaTest do
  use Dbservice.DataCase, async: false

  @action_items "blended_learning_action_items"
  @conversations "blended_learning_conversations"

  test "defines the Action Item contract" do
    assert column_types(@action_items) == %{
             "completed_at" => "timestamp without time zone",
             "completed_by_conversation_id" => "bigint",
             "completed_by_email" => "character varying",
             "conversation_id" => "bigint",
             "due_on" => "date",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "owner" => "character varying",
             "position" => "integer",
             "status" => "character varying",
             "student_id" => "bigint",
             "text" => "text",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns(@action_items) == [
             "completed_at",
             "completed_by_conversation_id",
             "completed_by_email",
             "due_on"
           ]

    assert column_lengths(@action_items)["completed_by_email"] == 255

    assert foreign_keys(@action_items) == [
             {"blended_learning_action_items_completed_by_conversation_id_fkey",
              ["completed_by_conversation_id", "student_id"], "blended_learning_conversations",
              ["id", "student_id"], "NO ACTION"},
             {"blended_learning_action_items_conversation_id_fkey",
              ["conversation_id", "student_id"], "blended_learning_conversations",
              ["id", "student_id"], "NO ACTION"},
             {"blended_learning_action_items_student_id_fkey", ["student_id"], "student", ["id"],
              "NO ACTION"}
           ]
  end

  test "names the Action Item CHECKs, indexes and triggers" do
    assert check_names(@action_items) == [
             "bl_action_items_completed_by_email_check",
             "bl_action_items_completion_check",
             "bl_action_items_owner_check",
             "bl_action_items_position_check",
             "bl_action_items_status_check",
             "bl_action_items_text_check"
           ]

    assert indexes(@action_items) == [
             "CREATE UNIQUE INDEX bl_action_items_conversation_position_unique ON public.blended_learning_action_items USING btree (conversation_id, \"position\")",
             "CREATE INDEX bl_action_items_open_student_idx ON public.blended_learning_action_items USING btree (student_id) WHERE ((status)::text = 'open'::text)",
             "CREATE UNIQUE INDEX blended_learning_action_items_pkey ON public.blended_learning_action_items USING btree (id)"
           ]

    assert triggers(@action_items) == [
             {"bl_action_items_conversation_kind", "blended_learning_reject_attempt_reference"},
             {"bl_action_items_immutable", "blended_learning_protect_action_item"}
           ]

    assert Repo.query!(
             "SELECT column_default FROM information_schema.columns WHERE table_name = $1 AND column_name = 'status'",
             [@action_items]
           ).rows == [["'open'::character varying"]]
  end

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
      insert_action_item(scope, conversation_id, %{owner: "parent", due_on: ~D[2026-10-25]})

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
             SELECT conversation_id, student_id, position, text, owner, due_on, status,
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
               ~D[2026-10-25],
               "done",
               closing_id,
               ~N[2026-10-27 11:00:00],
               "mentor@example.org"
             ]
           ]
  end

  test "rejects every Action Item update other than open to done, and every delete" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[closing_id]]}} = insert_conversation(scope, %{occurred_on: ~D[2026-10-27]})
    {:ok, %{rows: [[open_id]]}} = insert_action_item(scope, conversation_id, %{position: 1})

    {:ok, %{rows: [[done_id]]}} =
      insert_action_item(scope, conversation_id, %{
        position: 2,
        status: "done",
        completed_by_conversation_id: closing_id,
        completed_at: ~N[2026-10-27 11:00:00],
        completed_by_email: "mentor@example.org"
      })

    close = """
    status = 'done', completed_by_conversation_id = #{closing_id},
    completed_at = '2026-10-27 11:00:00', completed_by_email = 'mentor@example.org'
    """

    for {id, set} <- [
          {done_id,
           "status = 'open', completed_by_conversation_id = NULL, completed_at = NULL, completed_by_email = NULL"},
          {done_id, "completed_by_email = 'ops@example.org'"},
          {done_id, "text = 'Rewritten after closing.'"},
          {open_id, "text = 'Rewritten while open.'"},
          {open_id, "owner = 'mentor'"},
          {open_id, "updated_at = '2026-10-27 11:00:00'"},
          {open_id, close <> ", due_on = '2026-11-01'"},
          {open_id, close <> ", position = 3"}
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@action_items} SET #{set} WHERE id = $1", [id])
      end)
    end

    for id <- [open_id, done_id] do
      assert_constraint(:check_violation, fn ->
        Repo.query("DELETE FROM #{@action_items} WHERE id = $1", [id])
      end)
    end

    assert Repo.query!(
             "SELECT id, status, text, due_on FROM #{@action_items} WHERE conversation_id = $1 ORDER BY id",
             [conversation_id]
           ).rows == [
             [open_id, "open", "Finish the chapter 3 worksheet.", nil],
             [done_id, "done", "Finish the chapter 3 worksheet.", nil]
           ]
  end

  test "rejects creating or closing an Action Item with an Attempt" do
    scope = insert_scope()
    {:ok, %{rows: [[conversation_id]]}} = insert_conversation(scope, %{})
    {:ok, %{rows: [[attempt_id]]}} = insert_attempt(scope)
    {:ok, %{rows: [[item_id]]}} = insert_action_item(scope, conversation_id, %{position: 1})

    assert_constraint(:check_violation, fn ->
      insert_action_item(scope, attempt_id, %{position: 1})
    end)

    assert_constraint(:check_violation, fn ->
      insert_action_item(scope, conversation_id, %{
        position: 2,
        status: "done",
        completed_by_conversation_id: attempt_id,
        completed_at: ~N[2026-10-27 11:00:00],
        completed_by_email: "mentor@example.org"
      })
    end)

    assert_constraint(:check_violation, fn ->
      Repo.query(
        """
        UPDATE #{@action_items}
        SET status = 'done', completed_by_conversation_id = $2,
            completed_at = '2026-10-27 11:00:00', completed_by_email = 'mentor@example.org'
        WHERE id = $1
        """,
        [item_id, attempt_id]
      )
    end)

    assert Repo.query!("SELECT status FROM #{@action_items} WHERE id = $1", [item_id]).rows ==
             [["open"]]
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

  defp insert_attempt(scope) do
    insert_row(@conversations, %{
      student_id: scope.student_id,
      program_id: scope.program_id,
      mentor_user_id: scope.mentor_user_id,
      kind: "attempt",
      academic_year: "2026-2027",
      logged_by_email: "ops@example.org",
      occurred_on: ~D[2026-10-26]
    })
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

  defp column_types(table) do
    Repo.query!(
      """
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      """,
      [table]
    ).rows
    |> Map.new(fn [name, type] -> {name, type} end)
  end

  defp nullable_columns(table) do
    Repo.query!(
      """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1 AND is_nullable = 'YES'
      ORDER BY column_name
      """,
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp column_lengths(table) do
    Repo.query!(
      """
      SELECT column_name, character_maximum_length
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
        AND character_maximum_length IS NOT NULL
      """,
      [table]
    ).rows
    |> Map.new(fn [name, length] -> {name, length} end)
  end

  defp check_names(table) do
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
      [table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp indexes(table) do
    Repo.query!(
      """
      SELECT indexdef
      FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = $1
      ORDER BY indexname
      """,
      [table]
    ).rows
    |> Enum.map(fn [definition] -> definition end)
  end

  defp triggers(table) do
    Repo.query!(
      """
      SELECT trigger_record.tgname, procedure.proname
      FROM pg_trigger AS trigger_record
      JOIN pg_class AS relation ON relation.oid = trigger_record.tgrelid
      JOIN pg_proc AS procedure ON procedure.oid = trigger_record.tgfoid
      WHERE relation.relname = $1 AND NOT trigger_record.tgisinternal
      ORDER BY trigger_record.tgname
      """,
      [table]
    ).rows
    |> Enum.map(&List.to_tuple/1)
  end

  defp foreign_keys(table) do
    Repo.query!(
      """
      SELECT constraint_record.conname,
             ARRAY(
               SELECT attribute.attname
               FROM unnest(constraint_record.conkey) WITH ORDINALITY AS key(attnum, ordinality)
               JOIN pg_attribute AS attribute
                 ON attribute.attrelid = constraint_record.conrelid
                AND attribute.attnum = key.attnum
               ORDER BY key.ordinality
             ),
             referenced.relname,
             ARRAY(
               SELECT attribute.attname
               FROM unnest(constraint_record.confkey) WITH ORDINALITY AS key(attnum, ordinality)
               JOIN pg_attribute AS attribute
                 ON attribute.attrelid = constraint_record.confrelid
                AND attribute.attnum = key.attnum
               ORDER BY key.ordinality
             ),
             CASE constraint_record.confdeltype
               WHEN 'a' THEN 'NO ACTION'
               WHEN 'r' THEN 'RESTRICT'
               WHEN 'c' THEN 'CASCADE'
               WHEN 'n' THEN 'SET NULL'
               WHEN 'd' THEN 'SET DEFAULT'
             END
      FROM pg_constraint AS constraint_record
      JOIN pg_class AS relation ON relation.oid = constraint_record.conrelid
      JOIN pg_class AS referenced ON referenced.oid = constraint_record.confrelid
      JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
      WHERE namespace.nspname = 'public'
        AND relation.relname = $1
        AND constraint_record.contype = 'f'
      ORDER BY constraint_record.conname
      """,
      [table]
    ).rows
    |> Enum.map(&List.to_tuple/1)
  end
end
