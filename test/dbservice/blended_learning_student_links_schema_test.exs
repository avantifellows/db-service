defmodule Dbservice.BlendedLearningStudentLinksSchemaTest do
  use Dbservice.DataCase, async: false

  @table "blended_learning_student_links"

  test "defines the Student Links contract and indexes" do
    assert column_types() == %{
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "legacy_last_contact_month" => "date",
             "legacy_last_contact_on" => "date",
             "profile_doc_url" => "text",
             "screener_url" => "text",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns() == [
             "legacy_last_contact_month",
             "legacy_last_contact_on",
             "profile_doc_url",
             "screener_url"
           ]

    assert foreign_keys() == [{"student_id", "student", "NO ACTION"}]

    assert check_names() == [
             "bl_student_links_legacy_last_contact_month_check",
             "bl_student_links_profile_doc_url_check",
             "bl_student_links_screener_url_check"
           ]

    assert indexes() == [
             {"bl_student_links_student_unique", true, ["student_id"]},
             {"blended_learning_student_links_pkey", true, ["id"]}
           ]
  end

  test "stores at most one Student Links row per Student" do
    student_id = insert_student!()

    assert {:ok, %{rows: [[link_id]]}} =
             insert_link(student_id, %{
               profile_doc_url: "https://docs.google.com/document/d/abc123/edit",
               screener_url: "https://forms.gle/xyz789",
               legacy_last_contact_month: ~D[2026-08-01]
             })

    assert Repo.query!(
             """
             SELECT profile_doc_url, screener_url, legacy_last_contact_month
             FROM #{@table} WHERE id = $1
             """,
             [link_id]
           ).rows == [
             [
               "https://docs.google.com/document/d/abc123/edit",
               "https://forms.gle/xyz789",
               ~D[2026-08-01]
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

  test "accepts only the first of a month, or NULL, as the legacy last-contact month" do
    student_id = insert_student!()

    for date <- [~D[2026-08-02], ~D[2026-08-31], ~D[2024-02-29]] do
      assert_constraint(:check_violation, fn ->
        insert_link(student_id, %{legacy_last_contact_month: date})
      end)
    end

    assert {:ok, %{rows: [[link_id]]}} =
             insert_link(student_id, %{legacy_last_contact_month: nil})

    assert_constraint(:check_violation, fn ->
      Repo.query(
        "UPDATE #{@table} SET legacy_last_contact_month = '2026-09-15' WHERE id = $1",
        [link_id]
      )
    end)

    Repo.query!(
      "UPDATE #{@table} SET legacy_last_contact_month = '2026-09-01' WHERE id = $1",
      [link_id]
    )

    assert Repo.query!(
             "SELECT legacy_last_contact_month FROM #{@table} WHERE id = $1",
             [link_id]
           ).rows == [[~D[2026-09-01]]]
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

    Repo.query!(
      "UPDATE #{@table} SET legacy_last_contact_on = NULL, legacy_last_contact_month = '2026-09-01' WHERE id = $1",
      [link_id]
    )

    assert Repo.query!(
             "SELECT legacy_last_contact_on, legacy_last_contact_month FROM #{@table} WHERE id = $1",
             [link_id]
           ).rows == [[nil, ~D[2026-09-01]]]
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
        (student_id, profile_doc_url, screener_url, legacy_last_contact_month)
      VALUES ($1, $2, $3, $4)
      RETURNING id
      """,
      [
        student_id,
        attrs[:profile_doc_url],
        attrs[:screener_url],
        attrs[:legacy_last_contact_month]
      ]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end

  defp column_types do
    Repo.query!(
      """
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      """,
      [@table]
    ).rows
    |> Map.new(fn [name, type] -> {name, type} end)
  end

  defp nullable_columns do
    Repo.query!(
      """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1 AND is_nullable = 'YES'
      ORDER BY column_name
      """,
      [@table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp foreign_keys do
    Repo.query!(
      """
      SELECT kcu.column_name, ccu.table_name, rc.delete_rule
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name AND rc.constraint_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name = $1
      ORDER BY kcu.column_name
      """,
      [@table]
    ).rows
    |> Enum.map(fn [column, referenced_table, delete_rule] ->
      {column, referenced_table, delete_rule}
    end)
  end

  defp check_names do
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
      [@table]
    ).rows
    |> Enum.map(fn [name] -> name end)
  end

  defp indexes do
    Repo.query!(
      """
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = $1
      ORDER BY indexname
      """,
      [@table]
    ).rows
    |> Enum.map(fn [name, definition] ->
      [_, columns] = Regex.run(~r/\(([^)]*)\)$/, definition)
      {name, definition =~ "UNIQUE INDEX", String.split(columns, ", ")}
    end)
  end
end
