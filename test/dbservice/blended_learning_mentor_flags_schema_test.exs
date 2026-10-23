defmodule Dbservice.BlendedLearningMentorFlagsSchemaTest do
  use Dbservice.DataCase, async: false

  @flags "blended_learning_mentor_flags"
  @flag_views "blended_learning_flag_views"
  @conversations "blended_learning_conversations"

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
end
