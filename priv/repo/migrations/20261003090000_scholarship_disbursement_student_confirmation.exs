defmodule Dbservice.Repo.Migrations.ScholarshipDisbursementStudentConfirmation do
  use Ecto.Migration

  # The student confirms that her scholarship money actually reached her
  # (Sanghamitra, 3 Oct 2026; designed in the Phase 3 process walkthrough,
  # p14–15). Being paid and having RECEIVED the payment are two different
  # facts, and until now only the first was recorded.
  #
  # One column is the whole change. Everything else the flow needs already
  # exists:
  #
  #   * "I have not received it" is a FLAG, not a new table. Every thread in
  #     this product lives in scholarship_review_flags, and `kind` already
  #     carries a 'disbursement' value with `raised_by_role` already allowing
  #     'student' — the same machinery as the "₹1 not received" report, which
  #     is the same conversation at a smaller amount.
  #   * her bank statement is an ordinary document row, under its own doc_type
  #     so it cannot collide with the penny-drop statement she may have
  #     uploaded earlier.
  #
  # Nullable, no backfill: a NULL means she has not answered yet, which is
  # exactly true of every row that exists today.
  def up do
    alter table(:scholarship_disbursement_lot_members) do
      add :student_confirmed_at, :utc_datetime
    end
  end

  def down do
    alter table(:scholarship_disbursement_lot_members) do
      remove :student_confirmed_at
    end
  end
end
