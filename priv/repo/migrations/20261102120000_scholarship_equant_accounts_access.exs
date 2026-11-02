defmodule Dbservice.Repo.Migrations.ScholarshipEquantAccountsAccess do
  use Ecto.Migration

  # Equant handle the scholarship's payments: they already receive the ask to
  # put the ₹1 in, the confirmation that an account is good, and the request to
  # pay a lot (equant_scholarship@avantifellows.org is EQUANT_INBOX in the app).
  # Sanghamitra, 2 Nov 2026: give that mailbox the Accounts portal, on staging
  # and production both.
  #
  # `accounts` is the only role that opens that portal — there is no read-only
  # variant — so this also grants bill verification, bank flagging and
  # disbursement confirmation. That was put to her explicitly and chosen.
  #
  # A row written by hand on staging does not survive: `utils/fetch-data.sh`
  # rebuilds staging from a production dump, scholarship tables included. Only a
  # migration applied to BOTH environments keeps the access.
  #
  # DO UPDATE, not DO NOTHING: the seed in 20261001120000 took the DO NOTHING
  # route and silently left existing rows on their old roles. If this mailbox
  # already has a row, the point of the migration is to change what it can do.
  def up do
    execute("""
    INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
    VALUES ('equant_scholarship@avantifellows.org', 'Equant', 'accounts', true, NOW(), NOW())
    ON CONFLICT (email) DO UPDATE
      SET role = EXCLUDED.role,
          is_active = true,
          updated_at = NOW()
    """)
  end

  def down do
    # Revoke by deactivating rather than deleting: the row is referenced by the
    # decisions this account records, and a delete would take that trail with it.
    execute("""
    UPDATE scholarship_reviewers
    SET is_active = false, updated_at = NOW()
    WHERE email = 'equant_scholarship@avantifellows.org'
    """)
  end
end
