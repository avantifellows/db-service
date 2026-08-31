defmodule Dbservice.Repo.Migrations.AllowEmailOnlyHolisticPhaseAuditActors do
  use Ecto.Migration

  @tables [
    "holistic_mentorship_phase_state_transitions",
    "holistic_mentorship_phase_mutation_audits"
  ]

  def up do
    for table <- @tables do
      execute("ALTER TABLE #{table} ADD COLUMN actor_email varchar(255)")

      execute("""
      UPDATE #{table} audit
      SET actor_email = LOWER(TRIM(actor.email))
      FROM "user" actor
      WHERE actor.id = audit.actor_user_id
      """)

      execute("ALTER TABLE #{table} ALTER COLUMN actor_email SET NOT NULL")
      execute("ALTER TABLE #{table} ALTER COLUMN actor_user_id DROP NOT NULL")
    end
  end

  def down do
    for table <- Enum.reverse(@tables) do
      execute("ALTER TABLE #{table} ALTER COLUMN actor_user_id SET NOT NULL")
      execute("ALTER TABLE #{table} DROP COLUMN actor_email")
    end
  end
end
