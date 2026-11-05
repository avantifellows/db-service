defmodule Dbservice.Repo.Migrations.MergeRetiredSkills do
  @moduledoc """
  Issue #770. Four `skill` rows are retired and everything tagged with them is
  re-tagged with the skill that replaces it:

      Recall                 -> Fundamental
      Concept Knowledge      -> Direct Application
      Integrated Application -> Problem Solving
      Out of Box             -> Critical Thinking

  `skill` has no foreign keys, and its only consumer is `resource.skill_ids`
  (a `bigint[]` with no FK either), so deleting the four rows on its own would
  leave dangling ids behind in that array. This migration rewrites the arrays
  first and deletes the rows after.

  The pairs are resolved **by name**, trimmed and case-insensitively: the ids
  are not the same across environments, and prod stores "Out of Box " with a
  trailing space. A retired name that matches more than one row, or whose
  target is missing or ambiguous, aborts the migration - nothing is created to
  fill a gap, because a target skill invented here would silently become the
  one the CMS dropdown offers.

  A retired name that is simply absent is skipped instead. A database built
  from migrations alone - the test database, CI, a fresh checkout - has an
  empty `skill` table, and there is nothing there to merge or to lose.

  A resource tagged with both a retired skill and its target collapses to one
  entry rather than gaining a duplicate; the surviving ids keep the order the
  resource already had.

  Reversible: the retired `skill` rows and the pre-merge `skill_ids` of every
  resource touched are snapshotted into `bak_20261022120000_*` tables that
  `down/0` restores from and then drops. Those tables persist after `up/0` as
  the safety net for a change the data itself cannot reconstruct - once Recall
  and Fundamental are one id, nothing left on the resource says which of the
  two it carried.
  """
  use Ecto.Migration

  @pairs [
    {"Recall", "Fundamental"},
    {"Concept Knowledge", "Direct Application"},
    {"Integrated Application", "Problem Solving"},
    {"Out of Box", "Critical Thinking"}
  ]

  @map_table "bak_20261022120000_skill_merge_map"
  @skill_backup "bak_20261022120000_skill"
  @resource_backup "bak_20261022120000_resource"

  def up do
    if any_retired_skill?() do
      merge()
    end
  end

  def down do
    if table_exists?(@map_table) do
      restore()
    end
  end

  # Asked before anything is written, so the commands below can assume there is
  # a merge to do and `down/0` can assume the backup tables are there.
  defp any_retired_skill? do
    names = Enum.map_join(@pairs, ", ", fn {old, _} -> literal(String.downcase(old)) end)

    %{rows: [[count]]} =
      repo().query!("SELECT count(*) FROM skill WHERE lower(btrim(name)) IN (#{names})")

    count > 0
  end

  defp table_exists?(table) do
    %{rows: [[exists]]} = repo().query!("SELECT to_regclass(#{literal(table)}) IS NOT NULL")
    exists
  end

  defp merge do
    # The UPDATE below locks every affected resource row, so queue behind live
    # traffic instead of blocking it. SET LOCAL is scoped to this transaction.
    execute("SET LOCAL lock_timeout = '5s'")

    # --- The merge pairs, and the ids they resolve to in this environment ---
    values =
      Enum.map_join(@pairs, ",\n      ", fn {old, new} ->
        "(#{literal(old)}, #{literal(new)})"
      end)

    execute("""
    CREATE TABLE #{@map_table} (
      old_name text NOT NULL,
      new_name text NOT NULL,
      old_id   bigint,
      new_id   bigint
    );
    """)

    execute("""
    INSERT INTO #{@map_table} (old_name, new_name) VALUES
      #{values};
    """)

    execute("""
    DO $$
    DECLARE
      pair record;
      hits bigint;
    BEGIN
      FOR pair IN SELECT old_name, new_name FROM #{@map_table} LOOP
        SELECT count(*) INTO hits
        FROM skill
        WHERE lower(btrim(name)) = lower(btrim(pair.old_name));

        IF hits > 1 THEN
          RAISE EXCEPTION
            'merge_retired_skills: % skills are named %, cannot tell which one to retire',
            hits, quote_literal(pair.old_name);
        END IF;

        IF hits = 0 THEN
          DELETE FROM #{@map_table} m WHERE m.old_name = pair.old_name;
          CONTINUE;
        END IF;

        SELECT count(*) INTO hits
        FROM skill
        WHERE lower(btrim(name)) = lower(btrim(pair.new_name));

        IF hits <> 1 THEN
          RAISE EXCEPTION
            'merge_retired_skills: expected exactly one skill named %, found % - this migration does not create it',
            quote_literal(pair.new_name), hits;
        END IF;
      END LOOP;

      UPDATE #{@map_table} m
      SET old_id = (SELECT s.id FROM skill s
                     WHERE lower(btrim(s.name)) = lower(btrim(m.old_name))),
          new_id = (SELECT s.id FROM skill s
                     WHERE lower(btrim(s.name)) = lower(btrim(m.new_name)));

      -- A target that is itself being retired would make the result depend on
      -- the order the pairs happened to be applied in.
      SELECT count(*) INTO hits
      FROM #{@map_table} m
      WHERE m.old_id = m.new_id
         OR m.new_id IN (SELECT old_id FROM #{@map_table});

      IF hits <> 0 THEN
        RAISE EXCEPTION
          'merge_retired_skills: % pair(s) point at a skill that is itself retired',
          hits;
      END IF;
    END $$;
    """)

    # --- Snapshot what is about to be rewritten and deleted -----------------
    execute("""
    CREATE TABLE #{@skill_backup} AS
    SELECT s.* FROM skill s WHERE s.id IN (SELECT old_id FROM #{@map_table});
    """)

    execute("""
    CREATE TABLE #{@resource_backup} AS
    SELECT r.id, r.skill_ids, r.updated_at
    FROM resource r
    WHERE r.skill_ids && (SELECT array_agg(old_id) FROM #{@map_table});
    """)

    # --- Re-tag the resources ------------------------------------------------
    # Every id goes through the map (an id with no pair passes through), then
    # the result is de-duplicated on first appearance, so a resource that held
    # both a retired skill and its target keeps one entry in the slot the first
    # of the two occupied.
    execute("""
    UPDATE resource r
    SET skill_ids = merged.skill_ids,
        updated_at = NOW()
    FROM (
      SELECT src.id,
             ARRAY(
               SELECT g.skill_id
               FROM (
                 SELECT COALESCE(m.new_id, e.skill_id) AS skill_id,
                        min(e.ord) AS ord
                 FROM unnest(src.skill_ids) WITH ORDINALITY AS e(skill_id, ord)
                 LEFT JOIN #{@map_table} m ON m.old_id = e.skill_id
                 GROUP BY 1
               ) g
               ORDER BY g.ord
             ) AS skill_ids
      FROM resource src
      WHERE src.skill_ids && (SELECT array_agg(old_id) FROM #{@map_table})
    ) merged
    WHERE r.id = merged.id;
    """)

    # --- Retire the skills ---------------------------------------------------
    execute("DELETE FROM skill WHERE id IN (SELECT old_id FROM #{@map_table});")

    execute("""
    DO $$
    DECLARE
      stragglers bigint;
    BEGIN
      SELECT count(*) INTO stragglers
      FROM resource r
      WHERE r.skill_ids && (SELECT array_agg(old_id) FROM #{@map_table});

      IF stragglers <> 0 THEN
        RAISE EXCEPTION
          'merge_retired_skills: % resource(s) still reference a retired skill',
          stragglers;
      END IF;
    END $$;
    """)
  end

  defp restore do
    execute("SET LOCAL lock_timeout = '5s'")

    execute("""
    INSERT INTO skill (id, name, inserted_at, updated_at)
    SELECT id, name, inserted_at, updated_at FROM #{@skill_backup};
    """)

    # The restored ids came from the sequence in the first place, so it only
    # needs moving if it has since been left behind.
    execute("""
    SELECT setval(
      pg_get_serial_sequence('skill', 'id'),
      GREATEST((SELECT max(id) FROM skill), 1)
    );
    """)

    execute("""
    UPDATE resource r
    SET skill_ids = b.skill_ids,
        updated_at = b.updated_at
    FROM #{@resource_backup} b
    WHERE r.id = b.id;
    """)

    execute("DROP TABLE #{@resource_backup};")
    execute("DROP TABLE #{@skill_backup};")
    execute("DROP TABLE #{@map_table};")
  end

  defp literal(value), do: "'" <> String.replace(value, "'", "''") <> "'"
end
