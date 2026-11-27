defmodule Dbservice.Repo.Migrations.ScholarshipCohortFinancialYears do
  use Ecto.Migration

  # One scholar, one row per financial year (Program Team, 16 Nov 2026).
  #
  # The Earlier Cohorts import keyed a row on the Scholar ID alone, so a
  # scholar funded in three years could only ever be one row: the second year's
  # line read as a duplicate of the first and was refused. The team asked for
  # the key to become Scholar ID + Financial Year — one profile for her, a
  # separate financial record per year, and a re-upload of the same pair
  # correcting that year rather than duplicating it.
  #
  # Her PROFILE needs nothing new: it is still one application row.
  #
  # Her MONEY does. The import records what she was paid as confirmed lot
  # members and what she utilised as one approved bill, so that the Finance
  # Dashboard has exactly one source for each figure — and until now the only
  # thing that could say which year such a row belonged to was
  # `scholarship_applications.financial_year`, one value for the whole scholar.
  # That is precisely what stops speaking for her once she has several years.
  #
  # So the year moves onto the rows that carry the money:
  #
  #   lot members   the year the sheet put that payment under. The dashboard
  #                 still prefers the day it was PAID where the team recorded
  #                 one; this is what answers for an undated lump, which is
  #                 most of the historical money.
  #   bills         the year an imported utilisation figure belongs to, so
  #                 there is one such bill per year instead of one per scholar.
  #
  # Both are nullable and mean nothing for money the portal itself moved: a
  # real disbursement has a payment date and a real bill has the day Accounts
  # approved it, which is what the dashboard reads for those and what it will
  # go on reading.
  def up do
    alter table(:scholarship_disbursement_lot_members) do
      add :financial_year, :string
    end

    alter table(:scholarship_bills) do
      add :financial_year, :string
    end

    # Backfill ONLY the rows an earlier import wrote, and only from the year on
    # the scholar's own application — which, for those rows, is exactly where
    # that money's year was read from until today. Nothing else is touched:
    # giving a portal payment a year here would override the payment date the
    # dashboard is supposed to believe.
    execute(
      """
      UPDATE scholarship_disbursement_lot_members m
         SET financial_year = a.financial_year
        FROM scholarship_applications a
       WHERE a.id = m.application_id
         AND m.kind = 'imported'
         AND m.financial_year IS NULL
         AND a.financial_year IS NOT NULL
      """,
      ""
    )

    execute(
      """
      UPDATE scholarship_bills b
         SET financial_year = a.financial_year
        FROM scholarship_applications a
       WHERE a.id = b.application_id
         AND b.imported_at IS NOT NULL
         AND b.financial_year IS NULL
         AND a.financial_year IS NOT NULL
      """,
      ""
    )

    # How the import finds what it already wrote for a year, per scholar: both
    # reads are "this application, this year, imported".
    create index(:scholarship_disbursement_lot_members, [:application_id, :financial_year])
    create index(:scholarship_bills, [:application_id, :financial_year])
  end

  def down do
    drop index(:scholarship_bills, [:application_id, :financial_year])
    drop index(:scholarship_disbursement_lot_members, [:application_id, :financial_year])

    alter table(:scholarship_bills) do
      remove :financial_year
    end

    alter table(:scholarship_disbursement_lot_members) do
      remove :financial_year
    end
  end
end
