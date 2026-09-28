defmodule Dbservice.Repo.Migrations.ScholarshipSelectionCap77 do
  use Ecto.Migration

  # The Year 2026 scholarship total is 77, not 88 (Program Team via Sanghamitra,
  # 28 Sep 2026, Phase 3 Part 1 testing).
  #
  # 88 was seeded by 20260916120000_scholarship_phase3_selection as the Q2 answer
  # and flagged there as "provisional while the team re-confirms". This is that
  # re-confirmation. The number lives on the cycle row precisely so revising it
  # is a data change rather than a release — the app reads
  # `scholarship_cycles.selection_cap` live and needs no deploy for this.
  #
  # Scoped to the ACTIVE cycle, matching how 88 was set, so a future year's row
  # keeps its own total. `down` restores 88 rather than nulling the column, which
  # would silently uncap the year.
  def up do
    execute(
      "UPDATE scholarship_cycles SET selection_cap = 77, updated_at = NOW() WHERE is_active = true"
    )
  end

  def down do
    execute(
      "UPDATE scholarship_cycles SET selection_cap = 88, updated_at = NOW() WHERE is_active = true"
    )
  end
end
