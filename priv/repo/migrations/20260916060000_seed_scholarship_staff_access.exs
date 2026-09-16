defmodule Dbservice.Repo.Migrations.SeedScholarshipStaffAccess do
  use Ecto.Migration

  # af-scholarship staff-portal access, as rows a migration owns.
  #
  # Why: until now only aman.bahuguna@ and poojita@ were created by a merged
  # migration (20260729060000_seed_scholarship_reference_data). Every other staff
  # grant was manual SQL pasted into one database, so any rebuild or re-seed of
  # staging dropped them — which is how Sanghamitra lost both portals on 15 Sep
  # 2026 and why 20260903110000's `UPDATE ... WHERE email = 'alekhya@...'` could
  # quietly touch 0 rows (it assumed a row that no merged migration creates).
  #
  # scholarship_reviewers.role is a comma-separated list read by
  # src/lib/staff-roles.ts; "admin" is the superset (every portal). Roles here:
  #   alekhya@     admin              Accounts owner (decision Q13, 3 Sep 2026)
  #   sanghamitra@ reviewer,accounts  PM — tests both portals
  #   ram@         reviewer,accounts  interview + accounts coordination
  #
  # Idempotent, so it is safe to re-run by hand on an environment whose migration
  # history has drifted (prod applies are not reliable — see the responded_at
  # drift of 7 Aug 2026).
  @staff [
    {"alekhya@avantifellows.org", "Alekhya", "admin"},
    {"sanghamitra@avantifellows.org", "Sanghamitra", "reviewer,accounts"},
    {"ram@avantifellows.org", "Ram", "reviewer,accounts"}
  ]

  def up do
    for {email, name, role} <- @staff do
      repo().query!(
        """
        INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
        VALUES ($1, $2, $3, true, NOW(), NOW())
        ON CONFLICT (email) DO UPDATE
          SET name = EXCLUDED.name,
              role = EXCLUDED.role,
              is_active = true,
              updated_at = NOW()
        """,
        [email, name, role]
      )
    end
  end

  # Deactivate rather than delete: scholarship_review_flags.reviewer_id and
  # scholarship_applications.bank_verified_by point here, and a rolled-back grant
  # should not blank out who reviewed what.
  def down do
    emails = Enum.map(@staff, fn {email, _, _} -> email end)

    repo().query!(
      "UPDATE scholarship_reviewers SET is_active = false, updated_at = NOW() WHERE email = ANY($1)",
      [emails]
    )
  end
end
