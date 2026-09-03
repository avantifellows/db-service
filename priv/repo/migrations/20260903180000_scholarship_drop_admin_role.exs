defmodule Dbservice.Repo.Migrations.ScholarshipDropAdminRole do
  use Ecto.Migration

  # af-scholarship Phase 2 follow-up (Poojita, 3 Sep 2026): there is no admin
  # role. Staff roles are `reviewer` and `accounts`; a row may hold both as a
  # comma-separated list ("reviewer,accounts"). Admin meant "both portals", so
  # existing admin rows keep both.
  def up do
    execute("UPDATE scholarship_reviewers SET role = 'reviewer,accounts' WHERE role = 'admin'")
  end

  def down do
    execute("UPDATE scholarship_reviewers SET role = 'admin' WHERE role = 'reviewer,accounts'")
  end
end
