defmodule Dbservice.BlendedLearningCommonActionItemKeysSchemaTest do
  use Dbservice.DataCase, async: false

  # The data step is exercised through the migration's own SQL (not a copy of it), since
  # the migration itself has already run on the test database.
  Code.require_file(
    "priv/repo/migrations/20261124142920_add_key_to_blended_learning_common_action_items.exs"
  )

  @migration Dbservice.Repo.Migrations.AddKeyToBlendedLearningCommonActionItems

  @common "blended_learning_common_action_items"

  describe "key" do
    test "is optional, and stores a lowercase snake_case key up to 64 characters" do
      assert {:ok, %{rows: [[plain_id]]}} = insert_common(%{})
      assert {:ok, %{rows: [[keyed_id]]}} = insert_common(%{key: "jee_form_reminder"})
      assert {:ok, _} = insert_common(%{key: "a"})
      assert {:ok, _} = insert_common(%{key: "phase2_reminder"})
      assert {:ok, _} = insert_common(%{key: "a" <> String.duplicate("b", 63)})

      assert Repo.query!("SELECT id, key FROM #{@common} WHERE id IN ($1, $2) ORDER BY id", [
               plain_id,
               keyed_id
             ]).rows == [[plain_id, nil], [keyed_id, "jee_form_reminder"]]
    end

    test "rejects a key that is not lowercase snake_case starting with a letter" do
      for key <- [
            "",
            " ",
            "JEE_FORM_REMINDER",
            "Jee_form_reminder",
            "1_reminder",
            "_jee_form_reminder",
            "jee-form-reminder",
            "jee form reminder",
            "jee_form_reminder ",
            "jee_form_reminder\n",
            "jée_form"
          ] do
        assert_constraint(:check_violation, fn -> insert_common(%{key: key}) end)
      end

      assert_constraint(:string_data_right_truncation, fn ->
        insert_common(%{key: "a" <> String.duplicate("b", 64)})
      end)
    end

    test "is held by at most one active item" do
      assert {:ok, %{rows: [[id]]}} = insert_common(%{key: "jee_form_reminder"})
      assert {:ok, %{rows: [[other_id]]}} = insert_common(%{})

      assert_constraint(:unique_violation, fn ->
        insert_common(%{key: "jee_form_reminder"})
      end)

      assert_constraint(:unique_violation, fn ->
        Repo.query("UPDATE #{@common} SET key = 'jee_form_reminder' WHERE id = $1", [other_id])
      end)

      # Different keys don't clash.
      assert {:ok, _} = insert_common(%{key: "scholarship_reminder"})

      assert Repo.query!("SELECT key FROM #{@common} WHERE id = $1", [id]).rows == [
               ["jee_form_reminder"]
             ]
    end

    test "a removed item keeps its key but doesn't block a new item with it" do
      assert {:ok, %{rows: [[removed_id]]}} = insert_common(%{key: "jee_form_reminder"})
      remove(removed_id)

      assert {:ok, %{rows: [[new_id]]}} = insert_common(%{key: "jee_form_reminder"})

      # A second removed item with the same key is fine too.
      remove(new_id)
      assert {:ok, %{rows: [[active_id]]}} = insert_common(%{key: "jee_form_reminder"})

      assert Repo.query!("SELECT id, key, removed_at IS NOT NULL FROM #{@common} ORDER BY id").rows ==
               [
                 [removed_id, "jee_form_reminder", true],
                 [new_id, "jee_form_reminder", true],
                 [active_id, "jee_form_reminder", false]
               ]

      # Restoring a removed item while another active one holds the key is rejected.
      assert_constraint(:unique_violation, fn ->
        Repo.query(
          "UPDATE #{@common} SET removed_at = NULL, removed_by_email = NULL WHERE id = $1",
          [removed_id]
        )
      end)
    end
  end

  describe "the migration's data step" do
    test "keys the lowest-id active JEE reminder, ignoring case and spacing" do
      {:ok, %{rows: [[removed_id]]}} = insert_common(%{text: "JEE Form Filling (Reminder)"})
      remove(removed_id)
      {:ok, %{rows: [[unrelated_id]]}} = insert_common(%{text: "JEE Form Filling"})

      {:ok, %{rows: [[reminder_id]]}} =
        insert_common(%{text: "  jee  form\tFILLING\n(Reminder) "})

      {:ok, %{rows: [[duplicate_id]]}} = insert_common(%{text: "JEE Form Filling (Reminder)"})

      assert %{num_rows: 1} = key_jee_form_reminder()

      assert keys() == [
               [removed_id, nil],
               [unrelated_id, nil],
               [reminder_id, "jee_form_reminder"],
               [duplicate_id, nil]
             ]

      # Re-running changes nothing.
      assert %{num_rows: 0} = key_jee_form_reminder()
      assert Enum.at(keys(), 2) == [reminder_id, "jee_form_reminder"]
    end

    test "leaves a database without a JEE reminder as it is" do
      assert %{num_rows: 0} = key_jee_form_reminder()

      {:ok, %{rows: [[id]]}} = insert_common(%{})
      {:ok, %{rows: [[removed_id]]}} = insert_common(%{text: "JEE Form Filling (Reminder)"})
      remove(removed_id)

      assert %{num_rows: 0} = key_jee_form_reminder()
      assert keys() == [[id, nil], [removed_id, nil]]
    end

    test "doesn't move the key off a renamed reminder that already holds it" do
      {:ok, %{rows: [[renamed_id]]}} =
        insert_common(%{text: "Fill the JEE Main form", key: "jee_form_reminder"})

      {:ok, %{rows: [[text_match_id]]}} = insert_common(%{text: "JEE Form Filling (Reminder)"})

      assert %{num_rows: 0} = key_jee_form_reminder()
      assert keys() == [[renamed_id, "jee_form_reminder"], [text_match_id, nil]]
    end
  end

  defp key_jee_form_reminder, do: Repo.query!(@migration.key_jee_form_reminder_sql())

  defp keys, do: Repo.query!("SELECT id, key FROM #{@common} ORDER BY id").rows

  defp remove(id) do
    %{num_rows: 1} =
      Repo.query!(
        "UPDATE #{@common} SET removed_at = now(), removed_by_email = 'admin@example.org' WHERE id = $1",
        [id]
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
