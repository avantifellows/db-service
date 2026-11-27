defmodule Dbservice.Repo.Migrations.CreateBlendedLearningMentorSupervisions do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads this table directly over
  # SQL, and its operator script loads the rows, so there is no schema/context/controller
  # here.
  #
  # A Supervision lets a team-lead Mentor (supervisor_user_id) view, read-only, the
  # Students of another Mentor (mentor_user_id) for one academic year: the supervised
  # Mentor's Mentee list, their Mentees' pages and their Flags. It grants no writes: the
  # Mentor mapped to a Student still logs for them. It follows the Mapping table's
  # lifecycle and audit columns: a Supervision is never deleted, it is ended, so who could
  # see whom, and when, survives.

  @table :blended_learning_mentor_supervisions

  def change do
    create table(@table) do
      add :supervisor_user_id, references(:user, on_delete: :nothing), null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :assigned_by_user_id, references(:user, on_delete: :nothing)
      add :assigned_by_email, :string, size: 255
      add :assignment_source, :string, null: false
      add :assignment_audit_reason, :string, size: 500
      add :ended_at, :utc_datetime
      add :ended_by_user_id, references(:user, on_delete: :nothing)
      add :ended_by_email, :string, size: 255
      add :end_source, :string
      add :end_reason, :string
      add :end_audit_reason, :string, size: 500

      timestamps(default: fragment("now()"), null: false)
    end

    # One running Supervision per pair and year. A Mentor may have more than one
    # supervisor, and a supervisor more than one Mentor.
    create unique_index(
             @table,
             [:supervisor_user_id, :mentor_user_id, :academic_year],
             where: "ended_at IS NULL",
             name: :blm_supervisions_active_pair_year_unique
           )

    create index(
             @table,
             [:mentor_user_id, :academic_year],
             where: "ended_at IS NULL",
             name: :blm_supervisions_active_mentor_year_idx
           )

    create constraint(@table, :blm_supervisions_not_self_check,
             check: "supervisor_user_id <> mentor_user_id"
           )

    create constraint(
             @table,
             :blm_supervisions_lifecycle_check,
             check: """
             assignment_source <> '' AND
             (
               ended_at IS NULL AND ended_by_user_id IS NULL AND ended_by_email IS NULL AND
               end_source IS NULL AND end_reason IS NULL AND end_audit_reason IS NULL
               OR
               ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source <> '' AND
               end_reason IS NOT NULL AND end_reason <> '' AND ended_at >= started_at
             )
             """
           )

    create constraint(
             @table,
             :blm_supervisions_audit_fields_check,
             check: """
             (assigned_by_email IS NULL OR assigned_by_email ~ '[^[:space:]]') AND
             (assignment_audit_reason IS NULL OR assignment_audit_reason ~ '[^[:space:]]') AND
             (ended_by_email IS NULL OR ended_by_email ~ '[^[:space:]]') AND
             (end_audit_reason IS NULL OR end_audit_reason ~ '[^[:space:]]')
             """
           )
  end
end
