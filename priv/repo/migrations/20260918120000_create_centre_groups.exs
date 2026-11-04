defmodule Dbservice.Repo.Migrations.CreateCentreGroups do
  use Ecto.Migration

  @moduledoc """
  Makes `centre` a first-class group type, so centre membership can live in
  `group_user` / `enrollment_record` the way batch, school and grade membership
  already does.

  Nothing about `group` or `enrollment_record` changes structurally: both carry
  a free-form type string, so "centre" is simply a new value. What this
  migration adds is the `group` row every centre needs to be addressable:

    * a backfill for centres that already exist, and
    * an AFTER INSERT trigger so future centres get one automatically.

  The trigger (rather than doing this only in `Dbservice.Centres.create_centre/1`)
  is deliberate: centres are written by AF LMS directly into Postgres, bypassing
  db-service entirely, so an application-side hook would miss every centre that
  matters. Guaranteeing it in the database is the only way the invariant holds
  for both writers.

  `group_centre_child_unique` makes "one group row per centre" a real
  constraint rather than a convention — every lookup in `Dbservice.Centres` and
  `EnrollmentService` assumes exactly one.
  """

  def up do
    # Safe to create unconditionally: no centre group rows exist yet.
    create unique_index(:group, [:child_id],
             where: "type = 'centre'",
             name: :group_centre_child_unique
           )

    execute(ensure_group_function())

    execute("""
    CREATE TRIGGER centres_ensure_group_trigger
    AFTER INSERT ON centres
    FOR EACH ROW EXECUTE FUNCTION centres_ensure_group()
    """)

    # Backfill existing centres, active or not: the group row is identity, not
    # eligibility, and an inactive centre that is later reactivated should not
    # need a second migration.
    execute("""
    INSERT INTO "group" (type, child_id, inserted_at, updated_at)
    SELECT 'centre', c.id, now(), now()
    FROM centres c
    WHERE NOT EXISTS (
      SELECT 1 FROM "group" g WHERE g.type = 'centre' AND g.child_id = c.id
    )
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS centres_ensure_group_trigger ON centres")
    execute("DROP FUNCTION IF EXISTS centres_ensure_group()")

    # group_user and group_session both hold an unqualified FK to group(id), so
    # this DELETE raises rather than silently orphaning memberships if any
    # centre enrollment exists by the time it runs. That is the intended
    # outcome: rolling back past live membership data should fail loudly.
    execute("DELETE FROM \"group\" WHERE type = 'centre'")

    drop_if_exists index(:group, [:child_id], name: :group_centre_child_unique)
  end

  defp ensure_group_function do
    """
    CREATE OR REPLACE FUNCTION centres_ensure_group()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      INSERT INTO "group" (type, child_id, inserted_at, updated_at)
      SELECT 'centre', NEW.id, now(), now()
      WHERE NOT EXISTS (
        SELECT 1 FROM "group" WHERE type = 'centre' AND child_id = NEW.id
      );

      RETURN NEW;
    END;
    $$;
    """
  end
end
