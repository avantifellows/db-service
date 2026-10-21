defmodule Dbservice.BlendedLearningConversationPhotosSchemaTest do
  use Dbservice.DataCase, async: false

  @photos "blended_learning_conversation_photos"
  @conversations "blended_learning_conversations"

  test "defines the Conversation Photo contract" do
    assert column_types(@photos) == %{
             "byte_size" => "integer",
             "content_type" => "character varying",
             "conversation_id" => "bigint",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "position" => "integer",
             "s3_key" => "text"
           }

    assert nullable_columns(@photos) == []

    assert foreign_keys(@photos) == [
             {"blended_learning_conversation_photos_conversation_id_fkey", ["conversation_id"],
              "blended_learning_conversations", ["id"], "NO ACTION"}
           ]
  end

  test "names the Photo CHECKs, indexes and triggers" do
    assert check_names(@photos) == [
             "bl_conversation_photos_byte_size_check",
             "bl_conversation_photos_content_type_check",
             "bl_conversation_photos_position_check",
             "bl_conversation_photos_s3_key_check"
           ]

    assert indexes(@photos) == [
             "CREATE UNIQUE INDEX bl_conversation_photos_conversation_position_unique ON public.blended_learning_conversation_photos USING btree (conversation_id, \"position\")",
             "CREATE UNIQUE INDEX blended_learning_conversation_photos_pkey ON public.blended_learning_conversation_photos USING btree (id)"
           ]

    assert triggers(@photos) == [
             {"bl_conversation_photos_conversation_kind",
              "blended_learning_reject_attempt_reference"},
             {"bl_conversation_photos_immutable", "blended_learning_protect_conversation_photo"}
           ]

    assert Repo.query!(
             "SELECT column_default FROM information_schema.columns WHERE table_name = $1 AND column_name = 'inserted_at'",
             [@photos]
           ).rows == [["now()"]]
  end

  test "accepts Photos of 1 byte up to exactly 10 MiB and rejects empty or larger files" do
    conversation_id = insert_scope() |> insert_conversation() |> inserted_id()

    assert {:ok, _} = insert_photo(conversation_id, %{position: 1, byte_size: 1})
    assert {:ok, _} = insert_photo(conversation_id, %{position: 2, byte_size: 10_485_760})

    for byte_size <- [0, 10_485_761] do
      assert_constraint(:check_violation, fn ->
        insert_photo(conversation_id, %{position: 3, byte_size: byte_size})
      end)
    end

    assert Repo.query!(
             "SELECT position, byte_size FROM #{@photos} WHERE conversation_id = $1 ORDER BY position",
             [conversation_id]
           ).rows == [[1, 1], [2, 10_485_760]]
  end

  test "accepts image content types and rejects other content types or a blank S3 key" do
    conversation_id = insert_scope() |> insert_conversation() |> inserted_id()

    assert {:ok, _} = insert_photo(conversation_id, %{position: 1, content_type: "image/png"})
    assert {:ok, _} = insert_photo(conversation_id, %{position: 2, content_type: "image/heic"})

    for attrs <- [
          %{content_type: "application/pdf"},
          %{content_type: "audio/mpeg"},
          %{content_type: "IMAGE/jpeg"},
          %{content_type: "text/image/png"},
          %{s3_key: ""},
          %{s3_key: " \n\t"}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_photo(conversation_id, Map.put(attrs, :position, 3))
      end)
    end
  end

  test "numbers up to five Photos from 1, uniquely within a Conversation" do
    scope = insert_scope()
    conversation_id = scope |> insert_conversation() |> inserted_id()
    other_conversation_id = scope |> insert_conversation() |> inserted_id()

    for position <- 1..5 do
      assert {:ok, _} = insert_photo(conversation_id, %{position: position})
    end

    assert {:ok, _} = insert_photo(other_conversation_id, %{position: 1})

    for position <- [0, 6] do
      assert_constraint(:check_violation, fn ->
        insert_photo(other_conversation_id, %{position: position})
      end)
    end

    assert_constraint(:unique_violation, fn ->
      insert_photo(conversation_id, %{position: 3})
    end)

    assert Repo.query!(
             "SELECT conversation_id, position FROM #{@photos} WHERE conversation_id IN ($1, $2) ORDER BY conversation_id, position",
             [conversation_id, other_conversation_id]
           ).rows == [
             [conversation_id, 1],
             [conversation_id, 2],
             [conversation_id, 3],
             [conversation_id, 4],
             [conversation_id, 5],
             [other_conversation_id, 1]
           ]
  end

  test "rejects every Photo update and delete" do
    conversation_id = insert_scope() |> insert_conversation() |> inserted_id()
    photo_id = conversation_id |> insert_photo(%{}) |> inserted_id()

    for set <- [
          "s3_key = 'blended-learning/photos/replaced.jpg'",
          "content_type = 'image/png'",
          "byte_size = 1024",
          "position = 2",
          "inserted_at = '2026-10-20 10:00:00'",
          "s3_key = s3_key"
        ] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@photos} SET #{set} WHERE id = $1", [photo_id])
      end)
    end

    assert_constraint(:check_violation, fn ->
      Repo.query("DELETE FROM #{@photos} WHERE id = $1", [photo_id])
    end)

    assert Repo.query!(
             "SELECT conversation_id, s3_key, content_type, byte_size, position FROM #{@photos} WHERE id = $1",
             [photo_id]
           ).rows == [
             [conversation_id, "blended-learning/photos/meeting-1.jpg", "image/jpeg", 204_800, 1]
           ]
  end

  test "rejects attaching a Photo to an Attempt" do
    scope = insert_scope()
    attempt_id = scope |> insert_attempt() |> inserted_id()

    assert_constraint(:check_violation, fn -> insert_photo(attempt_id, %{}) end)

    assert Repo.query!("SELECT count(*) FROM #{@photos} WHERE conversation_id = $1", [
             attempt_id
           ]).rows == [[0]]
  end

  defp insert_scope do
    [[student_user_id], [mentor_user_id]] =
      Repo.query!("""
      INSERT INTO "user" (inserted_at, updated_at)
      VALUES (now(), now()), (now(), now())
      RETURNING id
      """).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Photos', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Photos', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{mentor_user_id: mentor_user_id, program_id: program_id, student_id: student_id}
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
      mode: "in_person",
      spoke_with: "both",
      duration_minutes: 40,
      summary: "Met the Student and parent at the centre."
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

  defp insert_photo(conversation_id, attrs) do
    insert_row(
      @photos,
      Map.merge(
        %{
          conversation_id: conversation_id,
          s3_key: "blended-learning/photos/meeting-1.jpg",
          content_type: "image/jpeg",
          byte_size: 204_800,
          position: 1
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
