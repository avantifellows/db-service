defmodule Dbservice.Repo.Migrations.AddCompletedRevisionToHolisticProfileGenerationStatuses do
  use Ecto.Migration

  def change do
    alter table(:holistic_mentorship_profile_generation_statuses) do
      add :completed_profile_revision, :integer
    end

    create constraint(
             :holistic_mentorship_profile_generation_statuses,
             :hm_profile_generation_statuses_completed_revision_check,
             check: "completed_profile_revision IS NULL OR completed_profile_revision > 0"
           )
  end
end
