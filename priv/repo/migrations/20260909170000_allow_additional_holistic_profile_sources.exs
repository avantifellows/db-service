defmodule Dbservice.Repo.Migrations.AllowAdditionalHolisticProfileSources do
  use Ecto.Migration

  @original """
  (form_id = '6a44a83d1184e717b920c499' AND af_session_id = 'EnableStudents_6a44a83d1184e717b920c499' AND entry_grade = 11)
  OR (form_id = '6a4deca8e030ebe34669fb0f' AND af_session_id = 'EnableStudents_6a4deca8e030ebe34669fb0f' AND entry_grade = 12)
  """
  @additional """
  OR (form_id = '6a76d43e24402e7cb501f34f' AND af_session_id = 'EMRSStudents_6a76d43e24402e7cb501f34f' AND entry_grade = 11)
  OR (form_id = '6a8843143834e2f94dd88f5d' AND af_session_id = 'MaharashtraStudents_6a8843143834e2f94dd88f5d' AND entry_grade = 11)
  """

  def up, do: replace_checks(@original <> @additional)

  # PostgreSQL rejects rollback if new-source rows exist. Keep those durable
  # Profiles intact; disable ETL source activation instead of deleting data.
  def down, do: replace_checks(@original)

  defp replace_checks(check) do
    for {table, name} <- [
          {:holistic_mentorship_profile_journeys, :hm_profile_journeys_source_check},
          {:holistic_mentorship_profile_generation_statuses,
           :hm_profile_generation_statuses_source_check}
        ] do
      drop constraint(table, name)
      create constraint(table, name, check: check)
    end
  end
end
