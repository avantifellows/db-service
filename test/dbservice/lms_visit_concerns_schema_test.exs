defmodule Dbservice.LmsVisitConcernsSchemaTest do
  use Dbservice.DataCase, async: false

  @tables ~w(lms_visit_concerns lms_visit_concern_mentions lms_visit_concern_events lms_visit_note_summaries)

  # Expected names and shapes follow the af_lms e2e mirror
  # `20261027140000_add_lms_visit_concerns.sql`, plus the two event guard CHECKs.
  test "columns match the af_lms mirror: UTC timestamp(0) columns default to now() except summarised_at" do
    ts = "timestamp without time zone"

    assert Repo.query!(
             """
             SELECT table_name::text, column_name::text, data_type::text,
                    datetime_precision, is_nullable::text, column_default::text
             FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = ANY($1)
             ORDER BY array_position($1, table_name::text), ordinal_position
             """,
             [@tables]
           ).rows == [
             [
               "lms_visit_concerns",
               "id",
               "bigint",
               nil,
               "NO",
               "nextval('lms_visit_concerns_id_seq'::regclass)"
             ],
             ["lms_visit_concerns", "school_code", "text", nil, "NO", nil],
             ["lms_visit_concerns", "kind", "text", nil, "NO", nil],
             ["lms_visit_concerns", "text", "text", nil, "NO", nil],
             ["lms_visit_concerns", "status", "text", nil, "YES", nil],
             ["lms_visit_concerns", "inserted_at", ts, 0, "NO", "now()"],
             ["lms_visit_concerns", "updated_at", ts, 0, "NO", "now()"],
             [
               "lms_visit_concern_mentions",
               "id",
               "bigint",
               nil,
               "NO",
               "nextval('lms_visit_concern_mentions_id_seq'::regclass)"
             ],
             ["lms_visit_concern_mentions", "concern_id", "bigint", nil, "NO", nil],
             ["lms_visit_concern_mentions", "visit_id", "bigint", nil, "NO", nil],
             ["lms_visit_concern_mentions", "snippet", "text", nil, "NO", nil],
             ["lms_visit_concern_mentions", "inserted_at", ts, 0, "NO", "now()"],
             [
               "lms_visit_concern_events",
               "id",
               "bigint",
               nil,
               "NO",
               "nextval('lms_visit_concern_events_id_seq'::regclass)"
             ],
             ["lms_visit_concern_events", "concern_id", "bigint", nil, "NO", nil],
             ["lms_visit_concern_events", "kind", "text", nil, "NO", nil],
             ["lms_visit_concern_events", "body", "text", nil, "YES", nil],
             ["lms_visit_concern_events", "author_email", "text", nil, "YES", nil],
             ["lms_visit_concern_events", "visit_id", "bigint", nil, "YES", nil],
             ["lms_visit_concern_events", "inserted_at", ts, 0, "NO", "now()"],
             ["lms_visit_note_summaries", "visit_id", "bigint", nil, "NO", nil],
             ["lms_visit_note_summaries", "fingerprint", "text", nil, "NO", nil],
             ["lms_visit_note_summaries", "prompt_version", "text", nil, "NO", nil],
             ["lms_visit_note_summaries", "summarised_at", ts, 0, "NO", nil]
           ]
  end

  test "constraint, foreign key, index and trigger names match the af_lms mirror" do
    assert Repo.query!(
             """
             SELECT conrelid::regclass::text, conname::text, contype::text,
                    CASE WHEN contype = 'f' THEN pg_get_constraintdef(oid) END
             FROM pg_constraint
             WHERE conrelid = ANY($1::text[]::regclass[])
             ORDER BY 1, 2
             """,
             [@tables]
           ).rows == [
             ["lms_visit_concern_events", "lms_visit_concern_events_author_check", "c", nil],
             [
               "lms_visit_concern_events",
               "lms_visit_concern_events_auto_reopened_check",
               "c",
               nil
             ],
             ["lms_visit_concern_events", "lms_visit_concern_events_body_check", "c", nil],
             [
               "lms_visit_concern_events",
               "lms_visit_concern_events_concern_id_fkey",
               "f",
               "FOREIGN KEY (concern_id) REFERENCES lms_visit_concerns(id)"
             ],
             ["lms_visit_concern_events", "lms_visit_concern_events_kind_check", "c", nil],
             ["lms_visit_concern_events", "lms_visit_concern_events_pkey", "p", nil],
             [
               "lms_visit_concern_events",
               "lms_visit_concern_events_visit_id_fkey",
               "f",
               "FOREIGN KEY (visit_id) REFERENCES lms_pm_school_visits(id)"
             ],
             [
               "lms_visit_concern_mentions",
               "lms_visit_concern_mentions_concern_id_fkey",
               "f",
               "FOREIGN KEY (concern_id) REFERENCES lms_visit_concerns(id) ON DELETE CASCADE"
             ],
             ["lms_visit_concern_mentions", "lms_visit_concern_mentions_pkey", "p", nil],
             [
               "lms_visit_concern_mentions",
               "lms_visit_concern_mentions_visit_id_fkey",
               "f",
               "FOREIGN KEY (visit_id) REFERENCES lms_pm_school_visits(id)"
             ],
             ["lms_visit_concerns", "lms_visit_concerns_kind_check", "c", nil],
             ["lms_visit_concerns", "lms_visit_concerns_kind_status_check", "c", nil],
             ["lms_visit_concerns", "lms_visit_concerns_pkey", "p", nil],
             ["lms_visit_concerns", "lms_visit_concerns_status_check", "c", nil],
             ["lms_visit_note_summaries", "lms_visit_note_summaries_pkey", "p", nil],
             [
               "lms_visit_note_summaries",
               "lms_visit_note_summaries_visit_id_fkey",
               "f",
               "FOREIGN KEY (visit_id) REFERENCES lms_pm_school_visits(id)"
             ]
           ]

    assert Repo.query!(
             """
             SELECT indexdef FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = ANY($1)
             ORDER BY indexname
             """,
             [@tables]
           ).rows == [
             [
               "CREATE INDEX lms_visit_concern_events_concern_id_inserted_at_index ON public.lms_visit_concern_events USING btree (concern_id, inserted_at)"
             ],
             [
               "CREATE UNIQUE INDEX lms_visit_concern_events_pkey ON public.lms_visit_concern_events USING btree (id)"
             ],
             [
               "CREATE UNIQUE INDEX lms_visit_concern_mentions_concern_id_visit_id_index ON public.lms_visit_concern_mentions USING btree (concern_id, visit_id)"
             ],
             [
               "CREATE UNIQUE INDEX lms_visit_concern_mentions_pkey ON public.lms_visit_concern_mentions USING btree (id)"
             ],
             [
               "CREATE INDEX lms_visit_concern_mentions_visit_id_index ON public.lms_visit_concern_mentions USING btree (visit_id)"
             ],
             [
               "CREATE UNIQUE INDEX lms_visit_concerns_pkey ON public.lms_visit_concerns USING btree (id)"
             ],
             [
               "CREATE INDEX lms_visit_concerns_school_code_kind_index ON public.lms_visit_concerns USING btree (school_code, kind)"
             ],
             [
               "CREATE UNIQUE INDEX lms_visit_note_summaries_pkey ON public.lms_visit_note_summaries USING btree (visit_id)"
             ]
           ]

    assert Repo.query!("""
           SELECT pg_get_triggerdef(oid) FROM pg_trigger
           WHERE tgrelid = 'lms_visit_concern_events'::regclass AND NOT tgisinternal
           """).rows == [
             [
               "CREATE TRIGGER lms_visit_concern_events_append_only BEFORE DELETE OR UPDATE ON public.lms_visit_concern_events FOR EACH ROW EXECUTE FUNCTION lms_protect_visit_concern_events()"
             ]
           ]
  end

  test "a Concern is open or resolved and a Highlight has no status" do
    assert {:ok, _} = insert_record("concern", "open")
    assert {:ok, _} = insert_record("concern", "resolved")
    assert {:ok, _} = insert_record("highlight", nil)

    assert_constraint(:check_violation, fn -> insert_record("concern", nil) end)
    assert_constraint(:check_violation, fn -> insert_record("highlight", "open") end)
    assert_constraint(:check_violation, fn -> insert_record("highlight", "resolved") end)
    assert_constraint(:check_violation, fn -> insert_record("concern", "closed") end)
    assert_constraint(:check_violation, fn -> insert_record("issue", nil) end)
    assert_constraint(:check_violation, fn -> insert_record("issue", "open") end)
  end

  test "a record mentions a Visit at most once and its Mentions go with it when it has no events" do
    visit_id = insert_visit()
    other_visit_id = insert_visit()
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "open")

    assert {:ok, _} = insert_mention(concern_id, visit_id)
    assert {:ok, _} = insert_mention(concern_id, other_visit_id)
    assert_constraint(:unique_violation, fn -> insert_mention(concern_id, visit_id) end)
    assert_constraint(:foreign_key_violation, fn -> insert_mention(concern_id, -1) end)

    Repo.query!("DELETE FROM lms_visit_concerns WHERE id = $1", [concern_id])

    assert Repo.query!("SELECT count(*) FROM lms_visit_concern_mentions").rows == [[0]]
  end

  test "an auto_reopened event names a Visit and has no author or body" do
    visit_id = insert_visit()
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "open")
    auto_reopened = %{kind: "auto_reopened", body: nil, author_email: nil, visit_id: visit_id}

    assert {:ok, _} = insert_event(concern_id, auto_reopened)

    for field <- [
          %{visit_id: nil},
          %{body: "Raised again"},
          %{author_email: "pm@avantifellows.org"}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_event(concern_id, Map.merge(auto_reopened, field))
      end)
    end

    assert_constraint(:check_violation, fn -> insert_event(concern_id, %{kind: "edited"}) end)

    assert_constraint(:foreign_key_violation, fn ->
      insert_event(concern_id, %{auto_reopened | visit_id: -1})
    end)
  end

  test "a human event needs a 1 to 2000 character body after trimming" do
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "resolved")

    for kind <- ["resolved", "reopened", "comment"],
        body <- [nil, "", "   ", " \n\t", String.duplicate("a", 2001)] do
      assert_constraint(:check_violation, fn ->
        insert_event(concern_id, %{kind: kind, body: body})
      end)
    end

    assert {:ok, _} = insert_event(concern_id, %{body: String.duplicate("a", 2000)})

    assert {:ok, _} =
             insert_event(concern_id, %{body: "  " <> String.duplicate("a", 2000) <> " "})

    assert {:ok, _} = insert_event(concern_id, %{body: "a"})
  end

  test "a human event has a non-blank author and names no Visit" do
    visit_id = insert_visit()
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "resolved")

    for kind <- ["resolved", "reopened", "comment"],
        field <- [
          %{author_email: nil},
          %{author_email: ""},
          %{author_email: "  "},
          %{author_email: "\t"},
          %{visit_id: visit_id}
        ] do
      assert_constraint(:check_violation, fn ->
        insert_event(concern_id, Map.merge(%{kind: kind}, field))
      end)
    end

    for kind <- ["resolved", "reopened", "comment"] do
      assert {:ok, _} = insert_event(concern_id, %{kind: kind})
    end
  end

  test "rejects every UPDATE and DELETE of an event" do
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "resolved")
    {:ok, %{rows: [[event_id]]}} = insert_event(concern_id, %{kind: "resolved"})

    for statement <- [
          "UPDATE lms_visit_concern_events SET body = body WHERE id = $1",
          "UPDATE lms_visit_concern_events SET body = 'Edited' WHERE id = $1",
          "UPDATE lms_visit_concern_events SET kind = 'comment' WHERE id = $1",
          "DELETE FROM lms_visit_concern_events WHERE id = $1"
        ] do
      assert_constraint(:check_violation, fn -> Repo.query(statement, [event_id]) end)
    end

    assert {:error,
            {:error,
             %Postgrex.Error{postgres: %{message: "Visit concern events are append-only"}}}} =
             Repo.transaction(
               fn ->
                 Repo.rollback(
                   Repo.query("DELETE FROM lms_visit_concern_events WHERE id = $1", [event_id])
                 )
               end,
               mode: :savepoint
             )

    assert Repo.query!(
             "SELECT kind, body FROM lms_visit_concern_events WHERE id = $1",
             [event_id]
           ).rows == [["resolved", "Spoke to the principal"]]
  end

  test "a record with events cannot be deleted" do
    {:ok, %{rows: [[concern_id]]}} = insert_record("concern", "resolved")
    assert {:ok, _} = insert_event(concern_id, %{kind: "resolved"})

    assert_constraint(:foreign_key_violation, fn ->
      Repo.query("DELETE FROM lms_visit_concerns WHERE id = $1", [concern_id])
    end)
  end

  test "a Visit has at most one Visit Note Summary and it records when it was summarised" do
    visit_id = insert_visit()

    assert {:ok, _} = insert_summary(visit_id, ~N[2026-10-28 06:30:00])

    assert_constraint(:unique_violation, fn ->
      insert_summary(visit_id, ~N[2026-10-28 07:00:00])
    end)

    assert_constraint(:not_null_violation, fn -> insert_summary(insert_visit(), nil) end)

    assert_constraint(:foreign_key_violation, fn ->
      insert_summary(-1, ~N[2026-10-28 06:30:00])
    end)

    assert Repo.query!(
             "SELECT fingerprint, prompt_version, summarised_at FROM lms_visit_note_summaries"
           ).rows == [["9f86d081", "visit-concerns-v1", ~N[2026-10-28 06:30:00]]]
  end

  defp insert_visit do
    [[visit_id]] =
      Repo.query!("""
      INSERT INTO lms_pm_school_visits (school_code, pm_email, visit_date, status, completed_at)
      VALUES ('70705', 'pm@avantifellows.org', '2026-10-12', 'completed', now())
      RETURNING id
      """).rows

    visit_id
  end

  defp insert_event(concern_id, attrs) do
    event =
      Map.merge(
        %{kind: "comment", body: "Spoke to the principal", author_email: "pm@avantifellows.org"},
        attrs
      )

    Repo.query(
      """
      INSERT INTO lms_visit_concern_events (concern_id, kind, body, author_email, visit_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
      """,
      [concern_id, event.kind, event.body, event.author_email, Map.get(event, :visit_id)]
    )
  end

  defp insert_summary(visit_id, summarised_at) do
    Repo.query(
      """
      INSERT INTO lms_visit_note_summaries (visit_id, fingerprint, prompt_version, summarised_at)
      VALUES ($1, '9f86d081', 'visit-concerns-v1', $2)
      """,
      [visit_id, summarised_at]
    )
  end

  defp insert_mention(concern_id, visit_id) do
    Repo.query(
      """
      INSERT INTO lms_visit_concern_mentions (concern_id, visit_id, snippet)
      VALUES ($1, $2, 'Lab keys are with the principal')
      RETURNING id
      """,
      [concern_id, visit_id]
    )
  end

  defp insert_record(kind, status) do
    Repo.query(
      """
      INSERT INTO lms_visit_concerns (school_code, kind, text, status)
      VALUES ('70705', $1, 'Labs are locked during practicals', $2)
      RETURNING id
      """,
      [kind, status]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
