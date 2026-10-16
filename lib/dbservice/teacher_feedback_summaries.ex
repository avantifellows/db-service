defmodule Dbservice.TeacherFeedbackSummaries do
  @moduledoc """
  Reads and writes the LLM summary columns on `lms_teacher_feedback`.

  The table is LMS-owned (no Ecto schema; the LMS writes it directly). This only
  exists so the etl-next summaries flow can see which forms are already
  summarised and save new summaries. A form is one session, so rows are matched
  by `session_pk`.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  @doc "Summary state for the given sessions (active rows only)."
  def list_by_session_pks(session_pks) when is_list(session_pks) do
    from(f in "lms_teacher_feedback",
      where: f.session_pk in ^session_pks and is_nil(f.deleted_at),
      select: %{
        session_pk: f.session_pk,
        summary: f.summary,
        summary_prompt_version: f.summary_prompt_version,
        summary_fingerprint: f.summary_fingerprint,
        summary_generated_at: f.summary_generated_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Saves a summary onto the session's row. Returns `{:ok, count}` with the rows
  updated (0 when the session has no active feedback row) or `{:error, reason}`
  for a malformed body.
  """
  def put_summary(session_pk, attrs) do
    with {:ok, summary} <- fetch_map(attrs, "summary"),
         {:ok, prompt_version} <- fetch_string(attrs, "summary_prompt_version", 50),
         {:ok, fingerprint} <- fetch_string(attrs, "summary_fingerprint", 64) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {count, _} =
        from(f in "lms_teacher_feedback",
          where: f.session_pk == ^session_pk and is_nil(f.deleted_at)
        )
        |> Repo.update_all(
          set: [
            summary: summary,
            summary_prompt_version: prompt_version,
            summary_fingerprint: fingerprint,
            summary_generated_at: now,
            updated_at: now
          ]
        )

      {:ok, count}
    end
  end

  defp fetch_map(attrs, key) do
    case Map.get(attrs, key) do
      %{} = value -> {:ok, value}
      _ -> {:error, "#{key} must be an object"}
    end
  end

  defp fetch_string(attrs, key, max) do
    case Map.get(attrs, key) do
      value when is_binary(value) and byte_size(value) in 1..max//1 -> {:ok, value}
      _ -> {:error, "#{key} must be a non-empty string of at most #{max} characters"}
    end
  end
end
