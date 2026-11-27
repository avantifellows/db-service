defmodule Dbservice.Repo.Migrations.AddCoachingFieldsToStudent do
  use Ecto.Migration

  def up do
    # Blended Learning students are sent to an external coaching institute by
    # Avanti; these two columns record which one and in what mode, so the
    # coaching can be evaluated later. Both are nullable - they only apply to
    # Blended students, and ops collects them after enrolment. Adding nullable
    # columns with no default is metadata-only, so this does not scan `student`.
    #
    # `mode_of_coaching` is deliberately free text rather than a CHECK
    # constraint: the value set ("Online", "Offline", "No Coaching", ...) is not
    # settled yet, and a constraint would reject a new mode until a migration
    # ships. The changeset caps the length; a dropdown, if wanted, belongs in
    # the form schema.
    alter table(:student) do
      add :mode_of_coaching, :string, size: 50
      add :coaching_name, :string, size: 50
    end
  end

  def down do
    alter table(:student) do
      remove :coaching_name
      remove :mode_of_coaching
    end
  end
end
