defmodule Dbservice.BlendedLearningMentorFlagsSchemaTest do
  use Dbservice.DataCase, async: false

  @flags "blended_learning_mentor_flags"
  @flag_views "blended_learning_flag_views"
  @conversations "blended_learning_conversations"

  test "defines the Mentor Flag contract" do
    assert column_types(@flags) == %{
             "comment" => "text",
             "conversation_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "notification_sent_at" => "timestamp without time zone",
             "raised_by_email" => "character varying",
             "recipient" => "character varying",
             "student_id" => "bigint"
           }

    assert nullable_columns(@flags) == ["comment", "notification_sent_at"]
    assert column_lengths(@flags)["raised_by_email"] == 255

    assert foreign_keys(@flags) == [
             {"blended_learning_mentor_flags_conversation_id_fkey",
              ["conversation_id", "student_id"], "blended_learning_conversations",
              ["id", "student_id"], "NO ACTION"},
             {"blended_learning_mentor_flags_student_id_fkey", ["student_id"], "student", ["id"],
              "NO ACTION"}
           ]
  end

  test "names the Mentor Flag CHECKs, indexes and triggers" do
    assert check_names(@flags) == [
             "bl_mentor_flags_comment_check",
             "bl_mentor_flags_raised_by_email_check",
             "bl_mentor_flags_recipient_check"
           ]

    assert indexes(@flags) == [
             "CREATE UNIQUE INDEX bl_mentor_flags_conversation_recipient_unique ON public.blended_learning_mentor_flags USING btree (conversation_id, recipient)",
             "CREATE INDEX bl_mentor_flags_inserted_at_idx ON public.blended_learning_mentor_flags USING btree (inserted_at DESC)",
             "CREATE UNIQUE INDEX blended_learning_mentor_flags_pkey ON public.blended_learning_mentor_flags USING btree (id)"
           ]

    assert triggers(@flags) == [
             {"bl_mentor_flags_conversation_kind", "blended_learning_reject_attempt_reference"},
             {"bl_mentor_flags_immutable", "blended_learning_protect_mentor_flag"}
           ]

    assert Repo.query!(
             "SELECT column_default FROM information_schema.columns WHERE table_name = $1 AND column_name = 'inserted_at'",
             [@flags]
           ).rows == [["now()"]]
  end

  test "allows one Mentor Flag per Flag Recipient on a Conversation" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()
    other_conversation_id = scope |> insert_conversation() |> inserted_id()

    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "physics"})
    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "maths"})
    assert {:ok, _} = insert_flag(scope, other_conversation_id, %{recipient: "physics"})

    assert_constraint(:unique_violation, fn ->
      insert_flag(scope, conversation_id, %{recipient: "physics", comment: "Raised again."})
    end)

    assert Repo.query!(
             "SELECT conversation_id, recipient FROM #{@flags} WHERE student_id = $1 ORDER BY conversation_id, recipient",
             [scope.student_id]
           ).rows == [
             [conversation_id, "maths"],
             [conversation_id, "physics"],
             [other_conversation_id, "physics"]
           ]
  end

  test "accepts the four Flag Recipients with or without a comment and rejects anything else" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()

    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "emotional_wellbeing"})
    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "physics", comment: nil})
    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "chemistry"})
    assert {:ok, _} = insert_flag(scope, conversation_id, %{recipient: "maths"})

    other_conversation_id = scope |> insert_conversation() |> inserted_id()

    for attrs <- [
          %{recipient: "biology"},
          %{recipient: "Maths"},
          %{recipient: ""},
          %{comment: ""},
          %{comment: " \n\t"},
          %{raised_by_email: ""},
          %{raised_by_email: "   "}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_flag(scope, other_conversation_id, attrs)
      end)
    end

    assert Repo.query!(
             "SELECT recipient, comment FROM #{@flags} WHERE student_id = $1 ORDER BY recipient",
             [scope.student_id]
           ).rows == [
             ["chemistry", "Student sounded anxious about the board exams."],
             ["emotional_wellbeing", "Student sounded anxious about the board exams."],
             ["maths", "Student sounded anxious about the board exams."],
             ["physics", nil]
           ]
  end

  test "lets the notifier set notification_sent_at exactly once and rejects every other change" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()
    flag_id = scope |> insert_flag(conversation_id, %{recipient: "chemistry"}) |> inserted_id()

    assert {:ok, %{num_rows: 1}} =
             Repo.query(
               "UPDATE #{@flags} SET notification_sent_at = '2026-10-21 09:30:00' WHERE id = $1",
               [flag_id]
             )

    for set <- [
          "notification_sent_at = '2026-10-22 09:30:00'",
          "notification_sent_at = NULL",
          "notification_sent_at = notification_sent_at"
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@flags} SET #{set} WHERE id = $1", [flag_id])
      end)
    end

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM #{@flags} WHERE id = $1", [flag_id])
    end)

    assert Repo.query!(
             "SELECT recipient, comment, raised_by_email, notification_sent_at FROM #{@flags} WHERE id = $1",
             [flag_id]
           ).rows == [
             [
               "chemistry",
               "Student sounded anxious about the board exams.",
               "mentor@example.org",
               ~N[2026-10-21 09:30:00]
             ]
           ]
  end

  test "rejects editing an unnotified Mentor Flag, including alongside setting notification_sent_at" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()
    flag_id = scope |> insert_flag(conversation_id, %{recipient: "maths"}) |> inserted_id()

    for set <- [
          "comment = 'Edited later.'",
          "comment = NULL",
          "recipient = 'physics'",
          "raised_by_email = 'other@example.org'",
          "inserted_at = '2026-10-20 10:00:00'",
          "comment = 'Edited later.', notification_sent_at = '2026-10-21 09:30:00'",
          "recipient = recipient"
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@flags} SET #{set} WHERE id = $1", [flag_id])
      end)
    end

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM #{@flags} WHERE id = $1", [flag_id])
    end)

    assert Repo.query!(
             "SELECT recipient, comment, raised_by_email, notification_sent_at FROM #{@flags} WHERE id = $1",
             [flag_id]
           ).rows == [
             [
               "maths",
               "Student sounded anxious about the board exams.",
               "mentor@example.org",
               nil
             ]
           ]
  end

  test "rejects a Student that does not own the flagged Conversation" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()

    assert_constraint(:foreign_key_violation, fn ->
      insert_flag(%{scope | student_id: scope.other_student_id}, conversation_id, %{})
    end)

    assert Repo.query!("SELECT count(*) FROM #{@flags} WHERE conversation_id = $1", [
             conversation_id
           ]).rows == [[0]]
  end

  test "rejects raising a Mentor Flag on an Attempt" do
    scope = insert_scope()
    attempt_id = scope |> insert_attempt() |> inserted_id()

    assert_constraint(:check_violation, fn -> insert_flag(scope, attempt_id, %{}) end)

    assert Repo.query!("SELECT count(*) FROM #{@flags} WHERE conversation_id = $1", [
             attempt_id
           ]).rows == [[0]]
  end

  test "defines the Flag View contract" do
    assert column_types(@flag_views) == %{
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "last_seen_at" => "timestamp without time zone",
             "updated_at" => "timestamp without time zone",
             "viewer_email" => "character varying",
             "viewer_user_id" => "bigint"
           }

    assert nullable_columns(@flag_views) == ["viewer_user_id"]
    assert column_lengths(@flag_views)["viewer_email"] == 255

    assert foreign_keys(@flag_views) == [
             {"blended_learning_flag_views_viewer_user_id_fkey", ["viewer_user_id"], "user",
              ["id"], "NO ACTION"}
           ]

    assert check_names(@flag_views) == ["bl_flag_views_viewer_email_check"]

    assert indexes(@flag_views) == [
             "CREATE UNIQUE INDEX bl_flag_views_viewer_email_unique ON public.blended_learning_flag_views USING btree (lower((viewer_email)::text))",
             "CREATE UNIQUE INDEX blended_learning_flag_views_pkey ON public.blended_learning_flag_views USING btree (id)"
           ]

    assert triggers(@flag_views) == []
  end

  test "records one Flag View per viewer email, ignoring case, and lets last_seen_at move on" do
    view_id =
      @flag_views
      |> insert_row(%{viewer_email: "A@x.org", last_seen_at: ~U[2026-10-21 09:00:00Z]})
      |> inserted_id()

    for email <- ["a@x.org", "A@X.ORG"] do
      assert_constraint(:unique_violation, fn ->
        insert_row(@flag_views, %{viewer_email: email, last_seen_at: ~U[2026-10-21 10:00:00Z]})
      end)
    end

    for email <- ["", " \t"] do
      assert_constraint(:check_violation, fn ->
        insert_row(@flag_views, %{viewer_email: email, last_seen_at: ~U[2026-10-21 10:00:00Z]})
      end)
    end

    assert {:ok, %{num_rows: 1}} =
             Repo.query(
               "UPDATE #{@flag_views} SET last_seen_at = '2026-10-22 08:15:00' WHERE id = $1",
               [view_id]
             )

    assert Repo.query!("SELECT viewer_email, last_seen_at FROM #{@flag_views}").rows == [
             ["A@x.org", ~N[2026-10-22 08:15:00]]
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
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Mentor Flags', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Mentor Flags', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      mentor_user_id: mentor_user_id,
      other_student_id: other_student_id,
      program_id: program_id,
      student_id: student_id
    }
  end

  defp insert_conversation(scope) do
    insert_row(@conversations, %{
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
      summary: "Talked through the Student's mock test results."
    })
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

  defp insert_flag(scope, conversation_id, attrs) do
    insert_row(
      @flags,
      Map.merge(
        %{
          conversation_id: conversation_id,
          student_id: scope.student_id,
          recipient: "emotional_wellbeing",
          comment: "Student sounded anxious about the board exams.",
          raised_by_email: "mentor@example.org"
        },
        attrs
      )
    )
  end

  defp inserted_id({:ok, %{rows: [[id]]}}), do: id

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
