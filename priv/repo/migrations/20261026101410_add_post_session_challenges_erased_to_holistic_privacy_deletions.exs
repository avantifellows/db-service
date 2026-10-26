defmodule Dbservice.Repo.Migrations.AddPostSessionChallengesErasedToHolisticPrivacyDeletions do
  use Ecto.Migration

  # LMS-owned (af_lms#457): the privacy tombstone records how many Post-Session Note
  # Challenge Category rows the erasure transaction deleted, next to the existing
  # profile/post-session/historical counts. Tombstones are immutable, so a count the
  # erasure forgets to record can never be added afterwards; this column makes the
  # Challenge Category part of the erasure visible on the tombstone itself.
  #
  # NOT NULL DEFAULT 0: existing tombstones predate Challenge Categories, so 0 is
  # their true count. A constant default is metadata-only (no table rewrite) and
  # does not fire the BEFORE UPDATE immutability trigger.
  #
  # The `>= 0` rule is a separate named CHECK rather than an edit of
  # hm_privacy_deletions_content_check, so the existing constraint is not rewritten.

  def up do
    # Queue behind live traffic instead of blocking it; scoped to this transaction.
    execute("SET LOCAL lock_timeout = '5s'")

    # One ALTER so the table is locked and scanned once.
    execute("""
    ALTER TABLE holistic_mentorship_privacy_deletions
      ADD COLUMN post_session_challenges_erased integer NOT NULL DEFAULT 0,
      ADD CONSTRAINT hm_privacy_deletions_challenges_erased_check
        CHECK (post_session_challenges_erased >= 0)
    """)
  end

  def down do
    # Drops any counts recorded since `up`; exercise only on disposable databases.
    execute("""
    ALTER TABLE holistic_mentorship_privacy_deletions
      DROP CONSTRAINT hm_privacy_deletions_challenges_erased_check,
      DROP COLUMN post_session_challenges_erased
    """)
  end
end
