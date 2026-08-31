defmodule Dbservice.HolisticMentorshipProfileSchemaTest do
  use Dbservice.DataCase, async: false

  @journeys "holistic_mentorship_profile_journeys"
  @profiles "holistic_mentorship_student_profiles"
  @summaries "holistic_mentorship_student_profile_summaries"

  test "defines the namespaced Student Profile storage contract without sensitive fields" do
    assert column_types(@journeys) == %{
             "af_session_id" => "character varying",
             "entry_grade" => "integer",
             "form_id" => "character varying",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "student_id" => "bigint",
             "updated_at" => "timestamp without time zone"
           }

    assert column_types(@profiles) == %{
             "answer_fingerprint" => "character varying",
             "generated_at" => "timestamp without time zone",
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "last_successful_etl_run_id" => "character varying",
             "profile_journey_id" => "bigint",
             "prompt_configuration_id" => "bigint",
             "revision" => "integer",
             "schema_fingerprint" => "character varying",
             "updated_at" => "timestamp without time zone",
             "warehouse_loaded_at" => "timestamp without time zone"
           }

    assert column_types(@summaries) == %{
             "id" => "bigint",
             "inserted_at" => "timestamp without time zone",
             "position" => "integer",
             "question_set_title" => "character varying",
             "student_profile_id" => "bigint",
             "summary" => "text",
             "updated_at" => "timestamp without time zone"
           }

    assert nullable_columns(@journeys) == []
    assert nullable_columns(@profiles) == []
    assert nullable_columns(@summaries) == []

    assert foreign_keys(@journeys) == [{"student_id", "student", "NO ACTION"}]

    assert foreign_keys(@profiles) == [
             {"profile_journey_id", @journeys, "NO ACTION"},
             {"prompt_configuration_id", "holistic_mentorship_prompt_configurations", "NO ACTION"}
           ]

    assert foreign_keys(@summaries) == [
             {"student_profile_id", @profiles, "CASCADE"}
           ]
  end

  test "keeps one immutable approved Profile journey per canonical Student" do
    student_id = insert_student!()
    journey_id = insert_journey!(student_id, 11)

    assert_constraint(:unique_violation, fn -> insert_journey(student_id, 11) end)

    assert_constraint(:check_violation, fn ->
      Repo.query("UPDATE #{@journeys} SET entry_grade = 12 WHERE id = $1", [journey_id])
    end)

    other_student_id = insert_student!()

    assert_constraint(:check_violation, fn ->
      Repo.query(
        """
        INSERT INTO #{@journeys} (student_id, form_id, af_session_id, entry_grade)
        VALUES ($1, '6a44a83d1184e717b920c499',
                'EnableStudents_6a44a83d1184e717b920c499', 12)
        """,
        [other_student_id]
      )
    end)
  end

  test "keys each positive-revision Profile by journey and Prompt Configuration" do
    journey_id = insert_student!() |> insert_journey!(11)
    first_configuration_id = insert_prompt_configuration!("openai/gpt-5-mini")
    second_configuration_id = insert_prompt_configuration!("google/gemini-2.5-flash")

    assert {:ok, _profile_id} = insert_profile(journey_id, first_configuration_id, 3)

    assert_constraint(:unique_violation, fn ->
      insert_profile(journey_id, first_configuration_id, 4)
    end)

    assert {:ok, _profile_id} = insert_profile(journey_id, second_configuration_id, 1)

    assert_constraint(:check_violation, fn ->
      insert_profile(journey_id, second_configuration_id, 0)
    end)
  end

  test "commits exactly five ordered non-empty Question Set summaries" do
    journey_id = insert_student!() |> insert_journey!(11)
    configuration_id = insert_prompt_configuration!("openai/gpt-5-nano")

    assert_constraint(:check_violation, fn ->
      {:ok, profile_id} = insert_profile(journey_id, configuration_id, 1)

      for position <- 1..4 do
        insert_summary!(profile_id, position, "Summary #{position}")
      end

      Repo.query("SET CONSTRAINTS ALL IMMEDIATE")
    end)

    other_configuration_id = insert_prompt_configuration!("openai/gpt-5")
    {:ok, profile_id} = insert_profile(journey_id, other_configuration_id, 1)

    for {position, summary} <- [
          {1, "First summary"},
          {2, "Second summary"},
          {3, "No response available"},
          {4, "Fourth summary"},
          {5, "Fifth summary"}
        ] do
      insert_summary!(profile_id, position, summary)
    end

    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")

    assert Repo.query!(
             "SELECT position, summary FROM #{@summaries} WHERE student_profile_id = $1 ORDER BY position",
             [profile_id]
           ).rows == [
             [1, "First summary"],
             [2, "Second summary"],
             [3, "No response available"],
             [4, "Fourth summary"],
             [5, "Fifth summary"]
           ]

    assert_constraint(:check_violation, fn -> insert_summary(profile_id, 0, "Invalid") end)
    assert_constraint(:check_violation, fn -> insert_summary(profile_id, 5, "") end)
    assert_constraint(:unique_violation, fn -> insert_summary(profile_id, 5, "Duplicate") end)
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

  defp foreign_keys(table) do
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
      [table]
    ).rows
    |> Enum.map(fn [column, referenced_table, delete_rule] ->
      {column, referenced_table, delete_rule}
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

  defp insert_journey!(student_id, entry_grade) do
    {:ok, %{rows: [[id]]}} = insert_journey(student_id, entry_grade)
    id
  end

  defp insert_journey(student_id, 11) do
    Repo.query(
      """
      INSERT INTO #{@journeys} (student_id, form_id, af_session_id, entry_grade)
      VALUES ($1, '6a44a83d1184e717b920c499',
              'EnableStudents_6a44a83d1184e717b920c499', 11)
      RETURNING id
      """,
      [student_id]
    )
  end

  defp insert_prompt_configuration!(model_id) do
    [[prompt_version_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_prompt_versions (version, template_text, template_hash)
        VALUES ($1, 'abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
        RETURNING id
        """,
        ["profile-schema-#{model_id}"]
      ).rows

    [[configuration_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_prompt_configurations (prompt_version_id, model_id)
        VALUES ($1, $2)
        RETURNING id
        """,
        [prompt_version_id, model_id]
      ).rows

    configuration_id
  end

  defp insert_profile(journey_id, configuration_id, revision) do
    case Repo.query(
           """
           INSERT INTO #{@profiles}
             (profile_journey_id, prompt_configuration_id, schema_fingerprint,
              answer_fingerprint, warehouse_loaded_at, generated_at, revision,
              last_successful_etl_run_id)
           VALUES ($1, $2, 'schema-v1', 'answers-v1', '2026-07-16 10:00:00',
                   '2026-07-16 10:05:00', $3, 'etl-run-1')
           RETURNING id
           """,
           [journey_id, configuration_id, revision]
         ) do
      {:ok, %{rows: [[profile_id]]}} -> {:ok, profile_id}
      error -> error
    end
  end

  defp insert_summary!(profile_id, position, summary) do
    {:ok, result} = insert_summary(profile_id, position, summary)
    result
  end

  defp insert_summary(profile_id, position, summary) do
    Repo.query(
      """
      INSERT INTO #{@summaries} (student_profile_id, position, question_set_title, summary)
      VALUES ($1, $2, $3, $4)
      """,
      [profile_id, position, "Question Set #{position}", summary]
    )
  end

  defp assert_constraint(code, query) do
    assert {:error, {:error, %Postgrex.Error{postgres: %{code: ^code}}}} =
             Repo.transaction(fn -> Repo.rollback(query.()) end, mode: :savepoint)
  end
end
