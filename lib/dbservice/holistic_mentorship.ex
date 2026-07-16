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
         :ok <- prompt_configuration_exists(record["prompt_configuration_id"]),
         :ok <- eligible_student(student_id, user_id) do
      %{
        record_ref: record_ref,
        student_id: student_id,
        prompt_configuration_id: record["prompt_configuration_id"],
        profile_state: "missing",
        profile_revision: nil
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
