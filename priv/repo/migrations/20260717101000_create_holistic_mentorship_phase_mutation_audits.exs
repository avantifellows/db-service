defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPhaseMutationAudits do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_phase_mutation_audits) do
      add :phase_plan_id,
          references(:holistic_mentorship_phase_plans, on_delete: :nothing),
          null: false

      # Deliberately not an FK: deletion audits must outlive never-opened Phase rows.
      add :phase_id, :bigint, null: false
      add :action, :string, null: false
      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :occurred_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:holistic_mentorship_phase_mutation_audits, [:phase_id, :occurred_at, :id],
             name: :hm_phase_mutation_audits_timeline_idx
           )

    create index(:holistic_mentorship_phase_mutation_audits, [:phase_plan_id],
             name: :hm_phase_mutation_audits_plan_idx
           )

    create index(:holistic_mentorship_phase_mutation_audits, [:actor_user_id],
             name: :hm_phase_mutation_audits_actor_idx
           )

    create constraint(
             :holistic_mentorship_phase_mutation_audits,
             :hm_phase_mutation_audits_phase_id_check,
             check: "phase_id > 0"
           )

    create constraint(
             :holistic_mentorship_phase_mutation_audits,
             :hm_phase_mutation_audits_action_check,
             check: "action IN ('created', 'definition_updated', 'reordered', 'deleted')"
           )
  end
end
