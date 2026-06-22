defmodule Dbservice.Repo.Migrations.AllowScoringStatusInEvalRunBenchmarks do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE acad_mentorship_eval_run_benchmarks
    DROP CONSTRAINT IF EXISTS am_eval_benchmarks_status_check
    """)

    execute("""
    ALTER TABLE acad_mentorship_eval_run_benchmarks
    ADD CONSTRAINT am_eval_benchmarks_status_check
    CHECK (scoring_status IN ('pending', 'scoring', 'scored', 'skipped', 'errored'))
    """)
  end

  def down do
    execute("""
    ALTER TABLE acad_mentorship_eval_run_benchmarks
    DROP CONSTRAINT IF EXISTS am_eval_benchmarks_status_check
    """)

    execute("""
    ALTER TABLE acad_mentorship_eval_run_benchmarks
    ADD CONSTRAINT am_eval_benchmarks_status_check
    CHECK (scoring_status IN ('pending', 'scored', 'skipped', 'errored'))
    """)
  end
end
