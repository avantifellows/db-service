defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPhaseStateTransitions do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_phase_state_transitions) do
      add :phase_id, references(:holistic_mentorship_phases, on_delete: :nothing), null: false
      add :from_state, :string, null: false
      add :to_state, :string, null: false
      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :occurred_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:holistic_mentorship_phase_state_transitions, [:phase_id, :occurred_at, :id],
             name: :hm_phase_state_transitions_timeline_idx
           )

    create index(:holistic_mentorship_phase_state_transitions, [:actor_user_id],
             name: :hm_phase_state_transitions_actor_idx
           )

    create constraint(
             :holistic_mentorship_phase_state_transitions,
             :hm_phase_state_transitions_states_check,
             check:
               "from_state IN ('locked', 'open') AND to_state IN ('locked', 'open') AND from_state <> to_state"
           )
  end
end
