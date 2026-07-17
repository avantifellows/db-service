defmodule DbserviceWeb.HolisticMentorshipProfilePublishController do
  use DbserviceWeb, :controller

  alias Dbservice.HolisticMentorship

  def create(conn, params) do
    case HolisticMentorship.publish_profile(params) do
      {:ok, result} ->
        json(conn, result)

      {:error, reason} ->
        {status, code, message} = error(reason)

        conn
        |> put_status(status)
        |> json(%{error: %{code: code, message: message}})
    end
  end

  defp error(:stale_profile_revision),
    do: {:conflict, "stale_profile_revision", "Profile revision is stale"}

  defp error(reason)
       when reason in [
              :dropout,
              :eligibility_inconsistent,
              :form_grade_mismatch,
              :form_not_approved,
              :grade_ineligible,
              :journey_source_conflict,
              :privacy_erased,
              :program_ineligible,
              :school_missing_or_ambiguous,
              :student_not_found,
              :user_not_found
            ],
       do: {:unprocessable_entity, Atom.to_string(reason), "Profile publication is not eligible"}

  defp error(_reason),
    do: {:unprocessable_entity, "invalid_request", "Profile publication request is invalid"}
end
