defmodule Dbservice.Repo.Migrations.CentreStudentsViewExistenceJoin do
  use Ecto.Migration

  @moduledoc """
  Replace the `centre_students` attribution tiebreak with a plain existence
  join on the centre's program.

  The original view (20260706120000) first picked each student's SINGLE
  attributed batch-program via a LATERAL ordered by
  `array_position(ARRAY['JNV CoE','JNV Nodal','JNV NVS'], program.name) LIMIT 1`,
  and only then compared that one program to the centre's. Any program not in
  that list ranks NULL, so a student whose batches span two non-JNV programs
  (e.g. Punjab "STP Test Series" + "Punjab CoE") got an arbitrary pick, and
  when the pick was the wrong one the student vanished from their centre.
  Found 2026-09-10: three Punjab CoE students (Bathinda, Mohali x2) missing
  from their centre for exactly this reason.

  The tiebreak only ever existed to guard against a student landing in two
  centres at the same school. Verified against production on 2026-09-10:
  of 5,446 students matching any active school-linked centre, zero match
  more than one, and the existence join changes membership by exactly the
  three missing students (+3 / -0). The guard is therefore dropped in favour
  of the obvious rule: a student is in centre C when they are in C's school,
  have a current grade enrollment, and hold ANY batch in C's program.

  A student who genuinely belongs to two centres at one school would now
  appear in both, which is the correct answer rather than a hidden one.
  """

  @up """
  CREATE OR REPLACE VIEW centre_students AS
  SELECT
    c.id            AS centre_id,
    gu.user_id      AS user_id,
    er.academic_year,
    gr.number       AS grade,
    c.program_id
  FROM centres c
  JOIN "group" g ON g.type = 'school' AND g.child_id = c.school_id
  JOIN group_user gu ON gu.group_id = g.id
  JOIN enrollment_record er ON er.user_id = gu.user_id
    AND er.group_type = 'grade'
    AND er.is_current = true
  LEFT JOIN grade gr ON er.group_id = gr.id
  WHERE c.is_active
    AND EXISTS (
      SELECT 1
      FROM group_user gub
      JOIN "group" gb ON gub.group_id = gb.id AND gb.type = 'batch'
      JOIN batch b ON gb.child_id = b.id
      WHERE gub.user_id = gu.user_id
        AND b.program_id = c.program_id
    )
  """

  # The original definition, so `mix ecto.rollback` restores it verbatim.
  @down """
  CREATE OR REPLACE VIEW centre_students AS
  SELECT
    c.id            AS centre_id,
    gu.user_id      AS user_id,
    er.academic_year,
    gr.number       AS grade,
    p.program_id
  FROM centres c
  JOIN "group" g ON g.type = 'school' AND g.child_id = c.school_id
  JOIN group_user gu ON gu.group_id = g.id
  JOIN enrollment_record er ON er.user_id = gu.user_id
    AND er.group_type = 'grade'
    AND er.is_current = true
  LEFT JOIN grade gr ON er.group_id = gr.id
  LEFT JOIN LATERAL (
    SELECT b.program_id
    FROM group_user gub
    JOIN "group" gb ON gub.group_id = gb.id AND gb.type = 'batch'
    JOIN batch b ON gb.child_id = b.id
    JOIN program pr ON pr.id = b.program_id
    WHERE gub.user_id = gu.user_id
    ORDER BY array_position(
      ARRAY['JNV CoE', 'JNV Nodal', 'JNV NVS']::text[],
      pr.name
    )
    LIMIT 1
  ) p ON true
  WHERE c.is_active
    AND p.program_id = c.program_id
  """

  def up, do: execute(@up)
  def down, do: execute(@down)
end
