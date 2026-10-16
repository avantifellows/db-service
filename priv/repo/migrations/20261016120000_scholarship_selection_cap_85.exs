defmodule Dbservice.Repo.Migrations.ScholarshipSelectionCap85 do
  use Ecto.Migration

  # The Year 2026 scholarship total is 85 (Program Team via Sanghamitra,
  # 16 Oct 2026, "as confirmed with Ram").
  #
  # Third value this cycle has carried: 88 was seeded by
  # 20260916120000_scholarship_phase3_selection as the Q2 answer and flagged
  # there as "provisional while the team re-confirms"; 77 was the 28 Sep
  # re-confirmation and was written in this migration under its old name, but
  # never reached an environment — the PR sat unmerged while Phase 3 was built,
  # and 85 overtook it. Renamed rather than edited in place so that it runs even
  # where the 77 version was applied by hand.
  #
  # The number lives on the cycle row precisely so revising it is a data change
  # rather than a release — the app reads `scholarship_cycles.selection_cap`
  # live and needs no deploy for this. It is also ENFORCED, not decorative:
  # `setSelectionOutcome` re-reads it inside its transaction and refuses a move
  # to Selected once the count is reached.
  #
  # Scoped to the ACTIVE cycle, matching how 88 and 77 were set, so a future
  # year's row keeps its own total. `down` restores 88 — the last value that
  # actually reached a database — rather than nulling the column, which would
  # silently uncap the year.
  def up do
    execute(
      "UPDATE scholarship_cycles SET selection_cap = 85, updated_at = NOW() WHERE is_active = true"
    )
  end

  def down do
    execute(
      "UPDATE scholarship_cycles SET selection_cap = 88, updated_at = NOW() WHERE is_active = true"
    )
  end
end
