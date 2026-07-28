alias Dbservice.Repo

# Seeds for the scholarship service (af-scholarship reads these tables directly).
# Raw SQL via Repo.query! — db-service has no Ecto schemas for the scholarship_*
# tables (they are created by the migration in this branch and owned/read by the
# scholarship app). Idempotent, so it is safe to run repeatedly (local or staging).
#
# Run standalone:  mix run priv/repo/seeds/scholarship.exs
# Reviewer emails: SEED_REVIEWER_EMAILS="a@avantifellows.org,b@avantifellows.org"
#
# NOTE: approved colleges (college.is_scholarship_approved) are intentionally NOT
# seeded here — the NIRF list doesn't reliably match college.name, and a partial
# flag would make the gate reject legitimately-approved colleges. With zero
# approved colleges the gate skips the college check (stays permissive), so the
# flow is testable without it. Seeding the real approved set is a focused #11 task.

IO.puts("→ Seeding scholarship data...")

slug = fn label ->
  label
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9]+/u, "_")
  |> String.trim("_")
end

# ── 1. One active, open cycle (idempotent by name) ──────────────────────────
cycle_name = "AY 2026 (test cycle)"

case Repo.query!("SELECT id FROM scholarship_cycles WHERE name = $1", [cycle_name]) do
  %{rows: []} ->
    Repo.query!(
      """
      INSERT INTO scholarship_cycles (name, opens_at, closes_at, is_active, inserted_at, updated_at)
      VALUES ($1, NOW() - interval '1 day', NOW() + interval '1 year', true, NOW(), NOW())
      """,
      [cycle_name]
    )

  _ ->
    Repo.query!(
      """
      UPDATE scholarship_cycles
      SET is_active = true,
          opens_at = NOW() - interval '1 day',
          closes_at = NOW() + interval '1 year',
          updated_at = NOW()
      WHERE name = $1
      """,
      [cycle_name]
    )
end

IO.puts("    ✅ Active cycle \"#{cycle_name}\"")

# ── 2. Dropdown option sets + options (normalized two-table shape) ───────────
option_sets = [
  {"occupation", "Occupation", 0,
   [
     "Agriculture / Farming",
     "Daily wage labour",
     "Self-employed / Small business",
     "Private sector employee",
     "Government employee",
     "Homemaker",
     "Unemployed",
     "Retired",
     "Not applicable"
   ]},
  {"school_type", "School type", 1,
   [
     "Jawahar Navodaya Vidyalaya (JNV)",
     "State Government School",
     "Kendriya Vidyalaya (KV)",
     "Eklavya Model Residential School (EMRS)"
   ]},
  {"coaching_centre", "Coaching centre", 2,
   [
     "Centre for Social Responsibility and Leadership (CSRL)",
     "Dakshana Foundation",
     "Ekalavya National Fellowship (ENF)",
     "Avanti Fellows"
   ]}
]

for {code, label, sort_order, values} <- option_sets do
  %{rows: [[set_id]]} =
    Repo.query!(
      """
      INSERT INTO scholarship_option_sets (code, label, allow_multi, sort_order, inserted_at, updated_at)
      VALUES ($1, $2, false, $3, NOW(), NOW())
      ON CONFLICT (code) DO UPDATE
        SET label = EXCLUDED.label, sort_order = EXCLUDED.sort_order, updated_at = NOW()
      RETURNING id
      """,
      [code, label, sort_order]
    )

  # Replace this set's options so re-running reflects any list change exactly.
  Repo.query!("DELETE FROM scholarship_options WHERE option_set_id = $1", [set_id])

  values
  |> Enum.with_index()
  |> Enum.each(fn {value, i} ->
    Repo.query!(
      """
      INSERT INTO scholarship_options (option_set_id, code, label, sort_order, is_active, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, true, NOW(), NOW())
      """,
      [set_id, slug.(value), value, i]
    )
  end)

  IO.puts("    ✅ Option set \"#{code}\" (#{length(values)} options)")
end

# ── 3. Reviewer accounts (idempotent by email) ──────────────────────────────
emails =
  System.get_env(
    "SEED_REVIEWER_EMAILS",
    "aman.bahuguna@avantifellows.org,poojita@avantifellows.org"
  )
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

for email <- emails do
  name = email |> String.split("@") |> hd()

  Repo.query!(
    """
    INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
    VALUES ($1, $2, 'reviewer', true, NOW(), NOW())
    ON CONFLICT (email) DO UPDATE SET is_active = true, updated_at = NOW()
    """,
    [email, name]
  )
end

IO.puts("    ✅ #{length(emails)} reviewer(s): #{Enum.join(emails, ", ")}")
IO.puts("Scholarship seeding done ✅")
