defmodule Dbservice.Repo.Migrations.AddArchivedStatus do
  use Ecto.Migration

  @moduledoc """
  Adds the `archived` status and its matching status group.

  Archiving a student mirrors dropout: it ends the student's current
  enrollments and writes a status enrollment record pointing at this group,
  so both rows have to exist in every environment, not only where seeds run.
  """

  def up do
    execute("""
    INSERT INTO status (title, inserted_at, updated_at)
    SELECT 'archived', timezone('UTC', now()), timezone('UTC', now())
    WHERE NOT EXISTS (SELECT 1 FROM status WHERE title = 'archived')
    """)

    execute("""
    INSERT INTO "group" (type, child_id, inserted_at, updated_at)
    SELECT 'status', s.id, timezone('UTC', now()), timezone('UTC', now())
    FROM status s
    WHERE s.title = 'archived'
      AND NOT EXISTS (
        SELECT 1 FROM "group" g WHERE g.type = 'status' AND g.child_id = s.id
      )
    """)
  end

  def down do
    # Only reversible while nothing references the group: an archived student
    # carries an enrollment record pointing at it, and that history is kept.
    execute("""
    DELETE FROM "group" g
    USING status s
    WHERE g.type = 'status'
      AND g.child_id = s.id
      AND s.title = 'archived'
      AND NOT EXISTS (
        SELECT 1 FROM enrollment_record e
        WHERE e.group_type = 'status' AND e.group_id = s.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM group_user gu WHERE gu.group_id = g.id
      )
    """)

    execute("""
    DELETE FROM status s
    WHERE s.title = 'archived'
      AND NOT EXISTS (
        SELECT 1 FROM "group" g WHERE g.type = 'status' AND g.child_id = s.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM enrollment_record e
        WHERE e.group_type = 'status' AND e.group_id = s.id
      )
    """)
  end
end
