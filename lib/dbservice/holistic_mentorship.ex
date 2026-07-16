defmodule Dbservice.HolisticMentorship do
  @moduledoc false

  import Ecto.Query

  alias Dbservice.Repo

  @mapping_table "holistic_mentorship_mentor_mentee_mappings"
  @eligibility_end_reasons ~w(student_dropout student_program_changed student_school_changed student_grade_changed)a
  @approved_profile_sources %{
    {"6a44a83d1184e717b920c499", "EnableStudents_6a44a83d1184e717b920c499", 11} => true,
    {"6a4deca8e030ebe34669fb0f", "EnableStudents_6a4deca8e030ebe34669fb0f", 12} => true
  }

  def end_active_mappings(student_id, reason) when reason in @eligibility_end_reasons do
    ended_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {count, _} =
      from(mapping in @mapping_table,
        where: field(mapping, :student_id) == ^student_id and is_nil(field(mapping, :ended_at))
      )
      |> Repo.update_all(
        set: [
          ended_at: ended_at,
          ended_by_user_id: nil,
          end_source: "db_service_student_eligibility",
          end_reason: Atom.to_string(reason),
          updated_at: ended_at
        ]
      )

    {:ok, count}
  end

  def end_active_mappings(_student_id, _reason), do: {:error, :invalid_end_reason}

  def profile_preflight(records) do
    Enum.map(records, &preflight_record/1)
  end

  def register_prompt_configuration(params) do
    with {:ok, fields} <- prompt_fields(params),
         :ok <- verify_template_hash(fields) do
      persist_prompt_configuration(fields)
    end
  end

  def activate_prompt_configuration(id) do
    Repo.transaction(fn ->
      Repo.query!(
        "SELECT pg_advisory_xact_lock(hashtext('holistic_mentorship_prompt_activation'))"
      )

      case prompt_configuration(id) do
        nil ->
          Repo.rollback(:prompt_configuration_not_found)

        _configuration ->
          Repo.query!(
            """
            UPDATE holistic_mentorship_prompt_configurations
            SET state = 'inactive', updated_at = now()
            WHERE state = 'active' AND id <> $1
            """,
            [id]
          )

          Repo.query!(
            """
            UPDATE holistic_mentorship_prompt_configurations
            SET state = 'active', updated_at = now()
            WHERE id = $1 AND state <> 'active'
            """,
            [id]
          )

          prompt_configuration(id)
      end
    end)
  end

  def record_profile_generation_status(params) do
    with {:ok, fields} <- generation_status_fields(params),
         :ok <- generation_status_references_exist(fields) do
      persist_generation_status(fields)
    end
  end

  def publish_profile(params) do
    with {:ok, fields} <- publication_fields(params) do
      persist_profile_publication(fields)
    end
  rescue
    Postgrex.Error -> {:error, :invalid_request}
  end

  defp publication_fields(%{
         "etl_run_id" => run_id,
         "student_id" => student_id,
         "source_user_id" => source_user_id,
         "form_id" => form_id,
         "af_session_id" => session_id,
         "entry_grade" => grade,
         "prompt_configuration_id" => configuration_id,
         "schema_fingerprint" => schema_fingerprint,
         "answer_fingerprint" => answer_fingerprint,
         "warehouse_loaded_at" => warehouse_loaded_at,
         "generated_at" => generated_at,
         "expected_profile_revision" => expected_revision,
         "force" => false,
         "summaries" => summaries
       }) do
    with {:ok, user_id} <- parse_source_user_id(source_user_id),
         {:ok, warehouse_loaded_at} <- parse_timestamp(warehouse_loaded_at),
         {:ok, generated_at} <- parse_timestamp(generated_at),
         :ok <- valid_summaries(summaries),
         fields = %{
           run_id: run_id,
           student_id: student_id,
           user_id: user_id,
           form_id: form_id,
           session_id: session_id,
           grade: grade,
           configuration_id: configuration_id,
           schema_fingerprint: schema_fingerprint,
           answer_fingerprint: answer_fingerprint,
           warehouse_loaded_at: warehouse_loaded_at,
           generated_at: generated_at,
           expected_revision: expected_revision,
           summaries: summaries
         },
         true <- valid_publication_fields?(fields) do
      {:ok, fields}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp publication_fields(_params), do: {:error, :invalid_request}

  defp valid_publication_fields?(fields) do
    Enum.all?([
      positive_integer?(fields.student_id),
      positive_integer?(fields.configuration_id),
      bounded_string?(fields.run_id, 255),
      bounded_string?(fields.schema_fingerprint, 255),
      bounded_string?(fields.answer_fingerprint, 255),
      is_nil(fields.expected_revision) or positive_integer?(fields.expected_revision),
      NaiveDateTime.compare(fields.generated_at, fields.warehouse_loaded_at) != :lt
    ])
  end

  defp bounded_string?(value, maximum),
    do: is_binary(value) and byte_size(value) in 1..maximum

  defp parse_source_user_id(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 and id <= 2_147_483_647 -> {:ok, id}
      _ -> {:error, :invalid_request}
    end
  rescue
    ArgumentError -> {:error, :invalid_request}
  end

  defp parse_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, DateTime.to_naive(datetime)}
      _ -> {:error, :invalid_request}
    end
  end

  defp parse_timestamp(_value), do: {:error, :invalid_request}

  defp valid_summaries(summaries) when is_list(summaries) and length(summaries) == 5 do
    if Enum.with_index(summaries, 1)
       |> Enum.all?(fn
         {%{
            "position" => position,
            "question_set_title" => title,
            "summary" => summary
          }, position} ->
           present_string?(String.trim(title)) and present_string?(String.trim(summary))

         _ ->
           false
       end),
       do: :ok,
       else: {:error, :invalid_request}
  rescue
    FunctionClauseError -> {:error, :invalid_request}
  end

  defp valid_summaries(_summaries), do: {:error, :invalid_request}

  defp publication_references(fields) do
    with :ok <- approved_profile_source(publication_source(fields)),
         :ok <- user_exists(fields.user_id),
         {:ok, student_id} <- student_id(fields.user_id),
         true <- student_id == fields.student_id,
         :ok <- prompt_configuration_exists(fields.configuration_id),
         :ok <- eligible_student(fields.student_id, fields.user_id) do
      :ok
    else
      false -> {:error, :student_not_found}
      error -> error
    end
  end

  defp publication_source(fields) do
    %{
      "form_id" => fields.form_id,
      "af_session_id" => fields.session_id,
      "entry_grade" => fields.grade
    }
  end

  defp persist_profile_publication(fields) do
    Repo.transaction(fn ->
      Repo.query!(
        "SELECT pg_advisory_xact_lock($1, $2)",
        [fields.student_id, 0],
        log: false
      )

      Repo.query!("SELECT 1 FROM student WHERE id = $1 FOR UPDATE", [fields.student_id],
        log: false
      )

      case publication_references(fields) do
        :ok -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end

      journey_id = insert_profile_journey!(fields)

      case generation_status_row(fields) do
        [[_id, "completed", outcome]] ->
          case current_profile(journey_id, fields.configuration_id) do
            {_profile_id, _fingerprint, revision} ->
              %{result: outcome, revision: revision}

            nil ->
              Repo.rollback(:invalid_request)
          end

        [[_id, "running", nil]] ->
          publish_running_profile!(journey_id, fields)

        _ ->
          Repo.rollback(:invalid_request)
      end
    end)
  end

  defp publish_running_profile!(journey_id, fields) do
    case current_profile(journey_id, fields.configuration_id) do
      nil when is_nil(fields.expected_revision) ->
        profile_id = insert_profile!(journey_id, fields)
        insert_profile_summaries!(profile_id, fields.summaries)
        complete_generation_status!(fields, "published")
        %{result: "published", revision: 1}

      {_profile_id, answer_fingerprint, revision}
      when revision == fields.expected_revision and
             answer_fingerprint == fields.answer_fingerprint ->
        complete_generation_status!(fields, "unchanged")
        %{result: "unchanged", revision: revision}

      {profile_id, _answer_fingerprint, revision} when revision == fields.expected_revision ->
        revision = revision + 1
        replace_profile!(profile_id, fields, revision)
        complete_generation_status!(fields, "replaced")
        %{result: "replaced", revision: revision}

      _ ->
        Repo.rollback(:stale_profile_revision)
    end
  end

  defp current_profile(journey_id, configuration_id) do
    case Repo.query!(
           """
           SELECT id, answer_fingerprint, revision
           FROM holistic_mentorship_student_profiles
           WHERE profile_journey_id = $1 AND prompt_configuration_id = $2
           FOR UPDATE
           """,
           [journey_id, configuration_id],
           log: false
         ).rows do
      [[id, answer_fingerprint, revision]] -> {id, answer_fingerprint, revision}
      [] -> nil
    end
  end

  defp insert_profile!(journey_id, fields) do
    [[profile_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profiles
          (profile_journey_id, prompt_configuration_id, schema_fingerprint,
           answer_fingerprint, warehouse_loaded_at, generated_at, revision,
           last_successful_etl_run_id)
        VALUES ($1, $2, $3, $4, $5, $6, 1, $7)
        RETURNING id
        """,
        [
          journey_id,
          fields.configuration_id,
          fields.schema_fingerprint,
          fields.answer_fingerprint,
          fields.warehouse_loaded_at,
          fields.generated_at,
          fields.run_id
        ],
        log: false
      ).rows

    profile_id
  end

  defp replace_profile!(profile_id, fields, revision) do
    Repo.query!(
      """
      UPDATE holistic_mentorship_student_profiles
      SET schema_fingerprint = $2, answer_fingerprint = $3, warehouse_loaded_at = $4,
          generated_at = $5, revision = $6, last_successful_etl_run_id = $7,
          updated_at = now()
      WHERE id = $1
      """,
      [
        profile_id,
        fields.schema_fingerprint,
        fields.answer_fingerprint,
        fields.warehouse_loaded_at,
        fields.generated_at,
        revision,
        fields.run_id
      ],
      log: false
    )

    Repo.query!(
      "DELETE FROM holistic_mentorship_student_profile_summaries WHERE student_profile_id = $1",
      [profile_id],
      log: false
    )

    insert_profile_summaries!(profile_id, fields.summaries)
  end

  defp insert_profile_journey!(fields) do
    case Repo.query!(
           """
           SELECT id, form_id, af_session_id, entry_grade
           FROM holistic_mentorship_profile_journeys
           WHERE student_id = $1
           FOR UPDATE
           """,
           [fields.student_id],
           log: false
         ).rows do
      [] ->
        [[journey_id]] =
          Repo.query!(
            """
            INSERT INTO holistic_mentorship_profile_journeys
              (student_id, form_id, af_session_id, entry_grade)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            """,
            [fields.student_id, fields.form_id, fields.session_id, fields.grade],
            log: false
          ).rows

        journey_id

      [[journey_id, form_id, session_id, grade]]
      when form_id == fields.form_id and session_id == fields.session_id and grade == fields.grade ->
        journey_id

      _ ->
        Repo.rollback(:journey_source_conflict)
    end
  end

  defp generation_status_row(fields) do
    Repo.query!(
      """
      SELECT id, state, completed_outcome
      FROM holistic_mentorship_profile_generation_statuses
      WHERE etl_run_id = $1 AND student_id = $2 AND form_id = $3
        AND af_session_id = $4 AND entry_grade = $5 AND prompt_configuration_id = $6
      FOR UPDATE
      """,
      [
        fields.run_id,
        fields.student_id,
        fields.form_id,
        fields.session_id,
        fields.grade,
        fields.configuration_id
      ],
      log: false
    ).rows
  end

  defp insert_profile_summaries!(profile_id, summaries) do
    Enum.each(summaries, fn summary ->
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profile_summaries
          (student_profile_id, position, question_set_title, summary)
        VALUES ($1, $2, $3, $4)
        """,
        [profile_id, summary["position"], summary["question_set_title"], summary["summary"]],
        log: false
      )
    end)
  end

  defp complete_generation_status!(fields, outcome) do
    Repo.query!(
      """
      UPDATE holistic_mentorship_profile_generation_statuses
      SET state = 'completed', completed_outcome = $2, updated_at = now()
      WHERE id = $1
      """,
      [generation_status_row(fields) |> hd() |> hd(), outcome],
      log: false
    )
  end

  def get_regeneration_request(request_key) when is_binary(request_key) do
    case Repo.query!(
           """
           SELECT request.student_id, student.user_id, request.prompt_configuration_id,
                  request.force, request.state, request.etl_run_id
           FROM holistic_mentorship_regeneration_requests AS request
           JOIN student ON student.id = request.student_id
           WHERE request.request_key = $1
           """,
           [request_key],
           log: false
         ).rows do
      [[student_id, user_id, configuration_id, force, state, etl_run_id]] ->
        with :ok <- eligible_student(student_id, user_id) do
          {:ok,
           %{
             student_id: student_id,
             prompt_configuration_id: configuration_id,
             force: force,
             state: state,
             etl_run_id: etl_run_id
           }}
        end

      [] ->
        {:error, :regeneration_request_not_found}
    end
  end

  def get_regeneration_request(_request_key), do: {:error, :regeneration_request_not_found}

  def update_regeneration_request_status(request_key, params) when is_binary(request_key) do
    with {:ok, fields} <- regeneration_status_fields(params) do
      Repo.transaction(fn -> transition_regeneration_request!(request_key, fields) end)
    end
  end

  def update_regeneration_request_status(_request_key, _params), do: {:error, :invalid_request}

  defp regeneration_status_fields(%{"etl_run_id" => run_id, "state" => state} = params) do
    error_code = params["error_code"]
    error_message = params["error_message"]

    valid_result =
      case state do
        state when state in ["running", "completed"] ->
          is_nil(error_code) and is_nil(error_message)

        "failed" ->
          bounded_optional_string?(error_code, 64) and
            bounded_optional_string?(error_message, 500)

        _ ->
          false
      end

    if present_string?(run_id) and byte_size(run_id) <= 255 and valid_result,
      do: {:ok, {run_id, state, error_code, error_message}},
      else: {:error, :invalid_request}
  end

  defp regeneration_status_fields(_params), do: {:error, :invalid_request}

  defp transition_regeneration_request!(request_key, fields) when is_binary(request_key) do
    case Repo.query!(
           """
           SELECT id, state, etl_run_id, error_code, error_message
           FROM holistic_mentorship_regeneration_requests
           WHERE request_key = $1
           FOR UPDATE
           """,
           [request_key],
           log: false
         ).rows do
      [[id, state, run_id, error_code, error_message]] ->
        transition_regeneration_request!(
          {id, state, run_id, error_code, error_message},
          fields
        )

      [] ->
        Repo.rollback(:regeneration_request_not_found)
    end
  end

  defp transition_regeneration_request!(
         {_id, state, run_id, error_code, error_message},
         {run_id, state, error_code, error_message}
       ),
       do: regeneration_status_response(state, run_id, error_code, error_message)

  defp transition_regeneration_request!({_id, _state, run_id, _, _}, {other_run_id, _, _, _})
       when not is_nil(run_id) and run_id != other_run_id,
       do: Repo.rollback(:etl_run_conflict)

  defp transition_regeneration_request!(
         {id, "queued", nil, nil, nil},
         {run_id, "running", nil, nil}
       ),
       do: update_regeneration_request!(id, "running", run_id, nil, nil)

  defp transition_regeneration_request!(
         {id, "running", run_id, nil, nil},
         {run_id, state, error_code, error_message}
       )
       when state in ["completed", "failed"],
       do: update_regeneration_request!(id, state, run_id, error_code, error_message)

  defp transition_regeneration_request!({_, state, _, _, _}, _fields)
       when state in ["completed", "failed"],
       do: Repo.rollback(:terminal_status_conflict)

  defp transition_regeneration_request!(_request, _fields),
    do: Repo.rollback(:invalid_transition)

  defp update_regeneration_request!(id, state, run_id, error_code, error_message) do
    [[state, run_id, error_code, error_message]] =
      Repo.query!(
        """
        UPDATE holistic_mentorship_regeneration_requests
        SET state = $2, etl_run_id = $3, error_code = $4, error_message = $5,
            updated_at = now()
        WHERE id = $1
        RETURNING state, etl_run_id, error_code, error_message
        """,
        [id, state, run_id, error_code, error_message],
        log: false
      ).rows

    regeneration_status_response(state, run_id, error_code, error_message)
  end

  defp regeneration_status_response(state, run_id, error_code, error_message) do
    %{
      state: state,
      etl_run_id: run_id,
      error_code: error_code,
      error_message: error_message
    }
  end

  defp generation_status_references_exist({_, student_id, _, _, _, configuration_id, _, _, _, _}) do
    case Repo.query!(
           """
           SELECT EXISTS(SELECT 1 FROM student WHERE id = $1),
                  EXISTS(SELECT 1 FROM holistic_mentorship_prompt_configurations WHERE id = $2)
           """,
           [student_id, configuration_id],
           log: false
         ).rows do
      [[true, true]] -> :ok
      _ -> {:error, :invalid_request}
    end
  end

  defp generation_status_fields(
         %{
           "etl_run_id" => etl_run_id,
           "student_id" => student_id,
           "form_id" => form_id,
           "af_session_id" => af_session_id,
           "entry_grade" => entry_grade,
           "prompt_configuration_id" => configuration_id,
           "state" => state
         } = params
       ) do
    outcome = params["completed_outcome"]
    error_code = params["error_code"]
    error_message = params["error_message"]

    if valid_generation_identity?(
         etl_run_id,
         student_id,
         form_id,
         af_session_id,
         entry_grade,
         configuration_id,
         state
       ) and
         valid_generation_result?(state, outcome, error_code, error_message) do
      {:ok,
       {etl_run_id, student_id, form_id, af_session_id, entry_grade, configuration_id, state,
        outcome, error_code, error_message}}
    else
      {:error, :invalid_request}
    end
  end

  defp generation_status_fields(_params), do: {:error, :invalid_request}

  defp valid_generation_identity?(
         run_id,
         student_id,
         form_id,
         session_id,
         grade,
         configuration_id,
         state
       ) do
    Enum.all?([
      present_string?(run_id),
      positive_integer?(student_id),
      Map.has_key?(@approved_profile_sources, {form_id, session_id, grade}),
      positive_integer?(configuration_id),
      state in ["queued", "running", "completed", "failed"]
    ])
  end

  defp present_string?(value), do: is_binary(value) and value != ""
  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp valid_generation_result?("completed", outcome, nil, nil),
    do: outcome in ["published", "replaced", "unchanged"]

  defp valid_generation_result?("failed", nil, error_code, error_message),
    do: bounded_optional_string?(error_code, 64) and bounded_optional_string?(error_message, 500)

  defp valid_generation_result?(state, nil, nil, nil) when state in ["queued", "running"],
    do: true

  defp valid_generation_result?(_state, _outcome, _error_code, _error_message), do: false

  defp bounded_optional_string?(nil, _maximum), do: true

  defp bounded_optional_string?(value, maximum),
    do: is_binary(value) and byte_size(value) in 1..maximum

  defp persist_generation_status(fields) do
    Repo.transaction(fn ->
      case generation_status(fields) do
        nil -> insert_generation_status!(fields)
        status -> transition_generation_status!(status, fields)
      end
    end)
  end

  defp generation_status(
         {run_id, student_id, form_id, session_id, grade, configuration_id, _, _, _, _}
       ) do
    case Repo.query!(
           """
           SELECT id, state, completed_outcome, error_code, error_message
           FROM holistic_mentorship_profile_generation_statuses
           WHERE etl_run_id = $1 AND student_id = $2 AND form_id = $3
             AND af_session_id = $4 AND entry_grade = $5 AND prompt_configuration_id = $6
           FOR UPDATE
           """,
           [run_id, student_id, form_id, session_id, grade, configuration_id],
           log: false
         ).rows do
      [[id, state, outcome, error_code, error_message]] ->
        {id, state, outcome, error_code, error_message}

      [] ->
        nil
    end
  end

  defp insert_generation_status!(
         {run_id, student_id, form_id, session_id, grade, configuration_id, "queued", nil, nil,
          nil} = fields
       ) do
    case Repo.query!(
           """
           INSERT INTO holistic_mentorship_profile_generation_statuses
             (etl_run_id, student_id, form_id, af_session_id, entry_grade,
              prompt_configuration_id, state)
           VALUES ($1, $2, $3, $4, $5, $6, 'queued')
           ON CONFLICT (etl_run_id, student_id, form_id, af_session_id, entry_grade,
                        prompt_configuration_id) DO NOTHING
           RETURNING state, completed_outcome, error_code, error_message
           """,
           [run_id, student_id, form_id, session_id, grade, configuration_id],
           log: false
         ).rows do
      [[state, outcome, error_code, error_message]] ->
        generation_status_response(state, outcome, error_code, error_message)

      [] ->
        generation_status(fields) |> transition_generation_status!(fields)
    end
  end

  defp insert_generation_status!(_fields), do: Repo.rollback(:invalid_transition)

  defp transition_generation_status!(
         {_id, current_state, current_outcome, current_code, current_message},
         {_, _, _, _, _, _, current_state, current_outcome, current_code, current_message}
       ),
       do:
         generation_status_response(current_state, current_outcome, current_code, current_message)

  defp transition_generation_status!(
         {id, "queued", nil, nil, nil},
         {_, _, _, _, _, _, "running", nil, nil, nil}
       ),
       do: update_generation_status!(id, "running", nil, nil, nil)

  defp transition_generation_status!(
         {id, "running", nil, nil, nil},
         {_, _, _, _, _, _, state, outcome, error_code, error_message}
       )
       when state in ["completed", "failed"],
       do: update_generation_status!(id, state, outcome, error_code, error_message)

  defp transition_generation_status!({_, state, _, _, _}, _fields)
       when state in ["completed", "failed"],
       do: Repo.rollback(:terminal_status_conflict)

  defp transition_generation_status!(_status, _fields), do: Repo.rollback(:invalid_transition)

  defp update_generation_status!(id, state, outcome, error_code, error_message) do
    [[state, outcome, error_code, error_message]] =
      Repo.query!(
        """
        UPDATE holistic_mentorship_profile_generation_statuses
        SET state = $2, completed_outcome = $3, error_code = $4, error_message = $5,
            updated_at = now()
        WHERE id = $1
        RETURNING state, completed_outcome, error_code, error_message
        """,
        [id, state, outcome, error_code, error_message],
        log: false
      ).rows

    generation_status_response(state, outcome, error_code, error_message)
  end

  defp generation_status_response(state, outcome, error_code, error_message) do
    %{
      state: state,
      completed_outcome: outcome,
      error_code: error_code,
      error_message: error_message
    }
  end

  defp prompt_fields(%{
         "prompt_version" => version,
         "template_text" => template_text,
         "template_hash" => template_hash,
         "model_id" => model_id
       }) do
    fields = {version, template_text, template_hash, model_id}

    if fields |> Tuple.to_list() |> Enum.all?(&(is_binary(&1) and &1 != "")),
      do: {:ok, fields},
      else: {:error, :invalid_request}
  end

  defp prompt_fields(_params), do: {:error, :invalid_request}

  defp verify_template_hash({_version, template_text, template_hash, _model_id}) do
    if sha256(template_text) == template_hash,
      do: :ok,
      else: {:error, :template_hash_mismatch}
  end

  defp persist_prompt_configuration({version, template_text, template_hash, model_id}) do
    Repo.transaction(fn ->
      prompt_version_id = prompt_version_id!(version, template_text, template_hash)

      [[id, state]] =
        Repo.query!(
          """
          INSERT INTO holistic_mentorship_prompt_configurations (prompt_version_id, model_id)
          VALUES ($1, $2)
          ON CONFLICT (prompt_version_id, model_id) DO UPDATE SET model_id = EXCLUDED.model_id
          RETURNING id, state
          """,
          [prompt_version_id, model_id]
        ).rows

      %{
        id: id,
        model_id: model_id,
        prompt_version: version,
        state: state,
        template_hash: template_hash
      }
    end)
  end

  defp prompt_version_id!(version, template_text, template_hash) do
    case Repo.query!(
           """
           INSERT INTO holistic_mentorship_prompt_versions (version, template_text, template_hash)
           VALUES ($1, $2, $3)
           ON CONFLICT (version) DO NOTHING
           RETURNING id
           """,
           [version, template_text, template_hash],
           log: false
         ).rows do
      [[id]] -> id
      [] -> existing_prompt_version_id!(version, template_text, template_hash)
    end
  end

  defp existing_prompt_version_id!(version, template_text, template_hash) do
    case Repo.query!(
           """
           SELECT id, template_text, template_hash
           FROM holistic_mentorship_prompt_versions
           WHERE version = $1
           """,
           [version]
         ).rows do
      [[id, ^template_text, ^template_hash]] -> id
      _ -> Repo.rollback(:prompt_version_conflict)
    end
  end

  defp prompt_configuration(id) do
    case Repo.query!(
           """
           SELECT configuration.id, configuration.model_id, version.version,
                  configuration.state, version.template_hash
           FROM holistic_mentorship_prompt_configurations AS configuration
           JOIN holistic_mentorship_prompt_versions AS version
             ON version.id = configuration.prompt_version_id
           WHERE configuration.id = $1
           """,
           [id]
         ).rows do
      [[id, model_id, version, state, template_hash]] ->
        %{
          id: id,
          model_id: model_id,
          prompt_version: version,
          state: state,
          template_hash: template_hash
        }

      [] ->
        nil
    end
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp preflight_record(record) do
    record_ref = record["record_ref"]

    with :ok <- production_record(record),
         {:ok, user_id} <- source_user_id(record),
         :ok <- user_exists(user_id),
         {:ok, student_id} <- student_id(user_id),
         :ok <- approved_profile_source(record),
         {:ok, journey_id} <- matching_profile_journey(student_id, record),
         :ok <- prompt_configuration_exists(record["prompt_configuration_id"]),
         :ok <- eligible_student(student_id, user_id) do
      {profile_state, profile_revision} =
        profile_state(
          journey_id,
          record["prompt_configuration_id"],
          record["answer_fingerprint"]
        )

      %{
        record_ref: record_ref,
        student_id: student_id,
        prompt_configuration_id: record["prompt_configuration_id"],
        profile_state: profile_state,
        profile_revision: profile_revision
      }
    else
      {:error, reason_code} -> rejected(record_ref, reason_code)
    end
  end

  defp production_record(%{"source_record_type" => "production"}), do: :ok
  defp production_record(_record), do: {:error, :test_record}

  defp source_user_id(%{"source_user_id" => source_user_id}) when is_binary(source_user_id) do
    case Integer.parse(source_user_id) do
      {user_id, ""} when user_id > 0 and user_id <= 2_147_483_647 -> {:ok, user_id}
      _ -> {:error, :malformed_source_id}
    end
  end

  defp source_user_id(_record), do: {:error, :malformed_source_id}

  defp user_exists(user_id) do
    case Repo.query!("SELECT 1 FROM \"user\" WHERE id = $1", [user_id], log: false).rows do
      [[1]] -> :ok
      [] -> {:error, :user_not_found}
    end
  end

  defp student_id(user_id) do
    case Repo.query!("SELECT id FROM student WHERE user_id = $1", [user_id], log: false).rows do
      [] -> {:error, :student_not_found}
      [[student_id]] -> {:ok, student_id}
      _ -> {:error, :ambiguous_student}
    end
  end

  defp approved_profile_source(record) do
    source = {record["form_id"], record["af_session_id"], record["entry_grade"]}

    cond do
      Map.has_key?(@approved_profile_sources, source) ->
        :ok

      record["form_id"] in ["6a44a83d1184e717b920c499", "6a4deca8e030ebe34669fb0f"] ->
        {:error, :form_grade_mismatch}

      true ->
        {:error, :form_not_approved}
    end
  end

  defp matching_profile_journey(student_id, record) do
    form_id = record["form_id"]
    af_session_id = record["af_session_id"]
    entry_grade = record["entry_grade"]

    case Repo.query!(
           """
           SELECT id, form_id, af_session_id, entry_grade
           FROM holistic_mentorship_profile_journeys
           WHERE student_id = $1
           """,
           [student_id],
           log: false
         ).rows do
      [] ->
        {:ok, nil}

      [[journey_id, ^form_id, ^af_session_id, ^entry_grade]] ->
        {:ok, journey_id}

      _ ->
        {:error, :journey_source_conflict}
    end
  end

  defp profile_state(nil, _prompt_configuration_id, _answer_fingerprint),
    do: {"missing", nil}

  defp profile_state(journey_id, prompt_configuration_id, answer_fingerprint) do
    case Repo.query!(
           """
           SELECT answer_fingerprint, revision
           FROM holistic_mentorship_student_profiles
           WHERE profile_journey_id = $1 AND prompt_configuration_id = $2
           """,
           [journey_id, prompt_configuration_id],
           log: false
         ).rows do
      [] -> {"missing", nil}
      [[^answer_fingerprint, revision]] -> {"unchanged", revision}
      [[_stored_answer_fingerprint, revision]] -> {"changed_answers", revision}
    end
  end

  defp prompt_configuration_exists(prompt_configuration_id)
       when is_integer(prompt_configuration_id) and prompt_configuration_id > 0 do
    case Repo.query!(
           "SELECT 1 FROM holistic_mentorship_prompt_configurations WHERE id = $1",
           [prompt_configuration_id],
           log: false
         ).rows do
      [[1]] -> :ok
      [] -> {:error, :prompt_configuration_not_found}
    end
  end

  defp prompt_configuration_exists(_prompt_configuration_id),
    do: {:error, :prompt_configuration_not_found}

  defp rejected(record_ref, reason_code) do
    %{record_ref: record_ref, reason_code: Atom.to_string(reason_code)}
  end

  defp eligible_student(student_id, user_id) do
    [[status, grade_id, grade_number]] =
      Repo.query!(
        "SELECT student.status, student.grade_id, grade.number FROM student LEFT JOIN grade ON grade.id = student.grade_id WHERE student.id = $1",
        [student_id],
        log: false
      ).rows

    with :ok <- not_dropout(status),
         :ok <- eligible_grade_number(grade_number),
         :ok <- eligible_program(user_id),
         :ok <- eligible_school(user_id) do
      consistent_grade(user_id, grade_id)
    end
  end

  defp not_dropout("dropout"), do: {:error, :dropout}
  defp not_dropout(_status), do: :ok

  defp eligible_grade_number(grade_number) when grade_number in [11, 12], do: :ok
  defp eligible_grade_number(_grade_number), do: {:error, :grade_ineligible}

  defp eligible_program(user_id) do
    case current_enrollment_ids(user_id, "program") do
      [[1]] -> :ok
      [] -> {:error, :program_ineligible}
      [[_other_program_id]] -> {:error, :program_ineligible}
      _ -> {:error, :eligibility_inconsistent}
    end
  end

  defp eligible_school(user_id) do
    case Repo.query!(
           """
           SELECT school.program_ids
           FROM enrollment_record
           LEFT JOIN school ON school.id = enrollment_record.group_id
           WHERE enrollment_record.user_id = $1
             AND enrollment_record.is_current
             AND enrollment_record.group_type = 'school'
           """,
           [user_id],
           log: false
         ).rows do
      [[program_ids]] when is_list(program_ids) ->
        if 1 in program_ids, do: :ok, else: {:error, :program_ineligible}

      _ ->
        {:error, :school_missing_or_ambiguous}
    end
  end

  defp consistent_grade(user_id, student_grade_id) do
    case current_enrollment_ids(user_id, "grade") do
      [] -> {:error, :grade_ineligible}
      [[^student_grade_id]] -> :ok
      _ -> {:error, :eligibility_inconsistent}
    end
  end

  defp current_enrollment_ids(user_id, group_type) do
    Repo.query!(
      "SELECT group_id FROM enrollment_record WHERE user_id = $1 AND is_current AND group_type = $2",
      [user_id, group_type],
      log: false
    ).rows
  end
end
