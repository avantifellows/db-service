defmodule Dbservice.HolisticMentorship do
  @moduledoc false

  import Ecto.Query

  alias Dbservice.Repo

  @mapping_table "holistic_mentorship_mentor_mentee_mappings"
  @eligibility_end_reasons ~w(student_dropout student_program_changed student_school_changed student_grade_changed)a

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
end
