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
          nil}
       ) do
    [[state, outcome, error_code, error_message]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_profile_generation_statuses
          (etl_run_id, student_id, form_id, af_session_id, entry_grade,
           prompt_configuration_id, state)
        VALUES ($1, $2, $3, $4, $5, $6, 'queued')
        RETURNING state, completed_outcome, error_code, error_message
        """,
        [run_id, student_id, form_id, session_id, grade, configuration_id],
        log: false
      ).rows

    generation_status_response(state, outcome, error_code, error_message)
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
