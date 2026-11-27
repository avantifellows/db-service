defmodule Dbservice.BlendedLearningConversationPhotosSchemaTest do
  use Dbservice.DataCase, async: false

  @photos "blended_learning_conversation_photos"
  @conversations "blended_learning_conversations"

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
end
