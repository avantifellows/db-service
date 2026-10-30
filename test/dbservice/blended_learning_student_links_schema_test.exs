defmodule Dbservice.BlendedLearningStudentLinksSchemaTest do
  use Dbservice.DataCase, async: false

  @table "blended_learning_student_links"

  test "stores at most one Student Links row per Student" do
    student_id = insert_student!()

    assert {:ok, %{rows: [[link_id]]}} =
             insert_link(student_id, %{
               profile_doc_url: "https://docs.google.com/document/d/abc123/edit",
               screener_url: "https://forms.gle/xyz789",
               legacy_last_contact_on: ~D[2026-08-17]
             })

    assert Repo.query!(
             """
             SELECT profile_doc_url, screener_url, legacy_last_contact_on
             FROM #{@table} WHERE id = $1
             """,
             [link_id]
           ).rows == [
             [
               "https://docs.google.com/document/d/abc123/edit",
               "https://forms.gle/xyz789",
               ~D[2026-08-17]
             ]
           ]

    assert_constraint(:unique_violation, fn -> insert_link(student_id, %{}) end)

    assert {:ok, _} = insert_link(insert_student!(), %{})
  end

  test "accepts only https URLs without whitespace, or NULL" do
    student_id = insert_student!()

    invalid_urls = [
      "http://docs.google.com/document/d/abc123",
      "https://docs.google.com/document/d/abc 123",
      "https://docs.google.com/document/d/abc123\n",
      "https://",
      "ftp://docs.google.com/document/d/abc123",
      "docs.google.com/document/d/abc123",
      " https://docs.google.com/document/d/abc123",
      ""
    ]

    for column <- [:profile_doc_url, :screener_url], url <- invalid_urls do
      assert_constraint(:check_violation, fn -> insert_link(student_id, %{column => url}) end)
    end

    assert {:ok, %{rows: [[link_id]]}} =
             insert_link(student_id, %{profile_doc_url: nil, screener_url: nil})

    for column <- ["profile_doc_url", "screener_url"] do
      assert_constraint(:check_violation, fn ->
        Repo.query("UPDATE #{@table} SET #{column} = 'http://example.org' WHERE id = $1", [
          link_id
        ])
      end)
    end

    Repo.query!(
      "UPDATE #{@table} SET profile_doc_url = $1, screener_url = $2 WHERE id = $3",
      ["https://example.org/profile", "https://example.org/screener", link_id]
    )

    assert Repo.query!(
             "SELECT profile_doc_url, screener_url FROM #{@table} WHERE id = $1",
             [link_id]
           ).rows == [["https://example.org/profile", "https://example.org/screener"]]
  end

  test "stores any day, or NULL, as the exact legacy last-contact date" do
    student_id = insert_student!()
    assert {:ok, %{rows: [[link_id]]}} = insert_link(student_id, %{})

    assert Repo.query!("SELECT legacy_last_contact_on FROM #{@table} WHERE id = $1", [link_id]).rows ==
             [[nil]]

    for date <- [~D[2026-09-17], ~D[2026-10-01], ~D[2026-08-31]] do
      Repo.query!(
        "UPDATE #{@table} SET legacy_last_contact_on = $1 WHERE id = $2",
        [date, link_id]
      )

      assert Repo.query!(
               "SELECT legacy_last_contact_on FROM #{@table} WHERE id = $1",
               [link_id]
             ).rows == [[date]]
    end
  end

  test "stores the latest Profile Doc conversation summary, or NULL" do
    assert {:ok, %{rows: [[link_id]]}} =
             insert_link(insert_student!(), %{
               legacy_last_contact_on: ~D[2026-08-17],
               legacy_conversation_summary: "Discussed mock test results."
             })

    assert {:ok, %{rows: [[empty_id]]}} = insert_link(insert_student!(), %{})

    assert Repo.query!(
             "SELECT legacy_conversation_summary FROM #{@table} WHERE id = ANY($1) ORDER BY id",
             [[link_id, empty_id]]
           ).rows == [["Discussed mock test results."], [nil]]

    Repo.query!(
      "UPDATE #{@table} SET legacy_conversation_summary = $1 WHERE id = $2",
      [String.duplicate("a", 2000), link_id]
    )

    assert Repo.query!(
             "SELECT char_length(legacy_conversation_summary) FROM #{@table} WHERE id = $1",
             [link_id]
           ).rows == [[2000]]
  end

  test "rejects a blank or over-long legacy conversation summary" do
    for summary <- ["", " ", "  \n\t ", String.duplicate("a", 2001)] do
      assert_constraint(:check_violation, fn ->
        insert_link(insert_student!(), %{legacy_conversation_summary: summary})
      end)
    end
  end

  test "restricts deleting a Student that has Student Links" do
    student_id = insert_student!()
    assert {:ok, _} = insert_link(student_id, %{})

    assert_constraint(:foreign_key_violation, fn ->
      Repo.query("DELETE FROM student WHERE id = $1", [student_id])
    end)
  end

  defp insert_student! do
    [[user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [user_id]
      ).rows

    student_id
  end

  defp insert_link(student_id, attrs) do
    Repo.query(
      """
      INSERT INTO #{@table}
        (student_id, profile_doc_url, screener_url, legacy_last_contact_on,
         legacy_conversation_summary)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
      """,
      [
        student_id,
        attrs[:profile_doc_url],
        attrs[:screener_url],
        attrs[:legacy_last_contact_on],
        attrs[:legacy_conversation_summary]
      ]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
