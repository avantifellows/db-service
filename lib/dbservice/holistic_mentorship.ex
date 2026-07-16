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
end
