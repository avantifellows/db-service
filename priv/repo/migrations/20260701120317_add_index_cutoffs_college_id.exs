defmodule Dbservice.Repo.Migrations.AddIndexCutoffsCollegeId do
  use Ecto.Migration

  # One index per migration (see review on #569): a CONCURRENTLY build can't run in a
  # transaction (@disable_ddl_transaction), and if one build fails only this migration is
  # retried — Ecto skips the ones that already completed. `create` (not create_if_not_exists)
  # surfaces an interrupted build's INVALID index so it can be dropped and rebuilt instead of
  # being silently skipped by a name-only check. The migration lock is kept (repo uses
  # migration_lock: :pg_advisory_lock), which does not block the concurrent build.
  # Index on cutoffs.college_id (FK lookup).
  @disable_ddl_transaction true

  def change do
    create index(:cutoffs, [:college_id], concurrently: true)
  end
end
