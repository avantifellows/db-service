defmodule Dbservice.Repo.Migrations.SeedScholarshipReferenceData do
  use Ecto.Migration

  # Reference/config data for the scholarship service (af-scholarship reads the
  # scholarship_* tables directly). Delivered as a migration, not a seeder, because
  # staging/prod deploys run `mix ecto.migrate` but not the seeds. Raw SQL — there
  # are no Ecto schemas for these tables. Idempotent (upsert / existence-checked)
  # so it is safe if any row already exists.
  #
  # NOTE: this also inserts an active "test cycle" so the app's flow isn't
  # "Applications are closed" in staging. That means it will create that cycle in
  # ANY environment this migration runs in — split the cycle out if prod must not
  # get a test cycle.

  @cycle_name "AY 2026 (test cycle)"

  @option_sets [
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

  @reviewers ["aman.bahuguna@avantifellows.org", "poojita@avantifellows.org"]

  defp slug(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end

  def up do
    # ── Active, open cycle (idempotent by name) ──────────────────────────────
    case repo().query!("SELECT id FROM scholarship_cycles WHERE name = $1", [@cycle_name]) do
      %{rows: []} ->
        repo().query!(
          """
          INSERT INTO scholarship_cycles (name, opens_at, closes_at, is_active, inserted_at, updated_at)
          VALUES ($1, NOW() - interval '1 day', NOW() + interval '1 year', true, NOW(), NOW())
          """,
          [@cycle_name]
        )

      _ ->
        repo().query!(
          """
          UPDATE scholarship_cycles
          SET is_active = true,
              opens_at = NOW() - interval '1 day',
              closes_at = NOW() + interval '1 year',
              updated_at = NOW()
          WHERE name = $1
          """,
          [@cycle_name]
        )
    end

    # ── Dropdown option sets + options (normalized two-table shape) ───────────
    for {code, label, sort_order, values} <- @option_sets do
      %{rows: [[set_id]]} =
        repo().query!(
          """
          INSERT INTO scholarship_option_sets (code, label, allow_multi, sort_order, inserted_at, updated_at)
          VALUES ($1, $2, false, $3, NOW(), NOW())
          ON CONFLICT (code) DO UPDATE
            SET label = EXCLUDED.label, sort_order = EXCLUDED.sort_order, updated_at = NOW()
          RETURNING id
          """,
          [code, label, sort_order]
        )

      repo().query!("DELETE FROM scholarship_options WHERE option_set_id = $1", [set_id])

      values
      |> Enum.with_index()
      |> Enum.each(fn {value, i} ->
        repo().query!(
          """
          INSERT INTO scholarship_options (option_set_id, code, label, sort_order, is_active, inserted_at, updated_at)
          VALUES ($1, $2, $3, $4, true, NOW(), NOW())
          """,
          [set_id, slug(value), value, i]
        )
      end)
    end

    # ── Reviewer accounts (idempotent by email) ──────────────────────────────
    for email <- @reviewers do
      name = email |> String.split("@") |> hd()

      repo().query!(
        """
        INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
        VALUES ($1, $2, 'reviewer', true, NOW(), NOW())
        ON CONFLICT (email) DO UPDATE SET is_active = true, updated_at = NOW()
        """,
        [email, name]
      )
    end
  end

  def down do
    codes = Enum.map(@option_sets, fn {code, _, _, _} -> code end)

    repo().query!(
      """
      DELETE FROM scholarship_options
      WHERE option_set_id IN (SELECT id FROM scholarship_option_sets WHERE code = ANY($1))
      """,
      [codes]
    )

    repo().query!("DELETE FROM scholarship_option_sets WHERE code = ANY($1)", [codes])
    repo().query!("DELETE FROM scholarship_reviewers WHERE email = ANY($1)", [@reviewers])
    repo().query!("DELETE FROM scholarship_cycles WHERE name = $1", [@cycle_name])
  end
end
