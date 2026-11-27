defmodule Dbservice.Repo.Migrations.ScholarshipPhase3Selection do
  use Ecto.Migration

  # af-scholarship Phase 3, slice 1 — Results & Selection (decisions locked with
  # Poojita on 16 Sep 2026).
  #
  # 1. scholarship_applications.student_id — the scholarship ID issued to every
  #    Selected student, format `TAS-2026-001`, sequential within the cycle
  #    (Q6). Deliberately NOT the Avanti `student_id`: many applicants have no
  #    AF record at all, and db-service's own note says `student_id`/`apaar_id`
  #    on `student` are not reliably unique — a matcher, not an identity. This
  #    one appears in her award email and on her portal, so it is scholarship-
  #    scoped and uniquely indexed. Null until issued.
  #
  # 2. scholarship_interview_sessions.finalized_at — selection runs PER SESSION
  #    (Q1), and finalizing one locks ONLY its Selected students while the
  #    waitlist stays a live pool promotable from any later session (Q4). So the
  #    lock belongs on the session, not the application.
  #
  # 3. scholarship_cycles.selection_cap — 88 for Year 2026 (Q2), provisional
  #    while the team re-confirms. On the cycle row rather than in code so
  #    re-confirming a different number is a data change, and 2027 gets its own.
  #    Null means uncapped.
  #
  # All additive and nullable -> deploy-safe, no backfill. `status` needs no
  # migration: it is a plain varchar with no check constraint, so the new
  # `selected` / `waitlisted` values are accepted as they are.
  def up do
    alter table(:scholarship_applications) do
      add :student_id, :string, size: 32
    end

    create unique_index(:scholarship_applications, [:student_id])

    alter table(:scholarship_interview_sessions) do
      add :finalized_at, :utc_datetime
    end

    alter table(:scholarship_cycles) do
      add :selection_cap, :integer
    end

    execute(
      "UPDATE scholarship_cycles SET selection_cap = 88, updated_at = NOW() WHERE is_active = true"
    )
  end

  def down do
    alter table(:scholarship_cycles) do
      remove :selection_cap
    end

    alter table(:scholarship_interview_sessions) do
      remove :finalized_at
    end

    drop unique_index(:scholarship_applications, [:student_id])

    alter table(:scholarship_applications) do
      remove :student_id
    end
  end
end
