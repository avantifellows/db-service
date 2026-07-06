defmodule Dbservice.Repo.Migrations.CreateCentreStudentsView do
  use Ecto.Migration

  @moduledoc """
  Students are not stored per-centre anywhere: a centre's roster has always
  been derived as "members of the centre's school whose (single) attributed
  batch-program matches the centre's program". Until now that derivation was
  reimplemented ad hoc by consumers (af_lms dashboard, school roster). This
  view gives the derivation one canonical, always-live home so consumers can
  simply `SELECT ... FROM centre_students WHERE centre_id = $1`.

  It is a plain (non-materialized) view: reads cost the same as the query
  consumers already run today, and it can never go stale.
  """

  def change do
    # The view attributes students to a centre by (school_id, program_id), so
    # two ACTIVE centres sharing that pair would silently claim the same
    # students twice (as the duplicate "JNV South Canara" centre did before
    # its cleanup on 2026-07-06). Enforce the invariant before creating the
    # view that depends on it.
    create unique_index(:centres, [:school_id, :program_id],
             where: "is_active AND school_id IS NOT NULL AND program_id IS NOT NULL",
             name: :centres_active_school_program_unique
           )

    # Design notes:
    # - Lean membership keys only (no user/student display columns), so the
    #   view does not block future ALTERs on those tables; consumers join for
    #   whatever they need.
    # - academic_year is exposed as a column (a view cannot take parameters);
    #   callers filter to the current year.
    # - The LATERAL picks each student's single attributed program FIRST
    #   (preference: CoE -> Nodal -> NVS), and only then compares it to the
    #   centre's program - so a student enrolled in both a CoE and a Nodal
    #   batch lands in exactly one centre. This mirrors the tiebreaker af_lms
    #   uses for its school roster. The preference matches by program NAME
    #   (the stable business key) rather than hardcoded ids: ids currently
    #   match across staging and production (verified 2026-07-06), but names
    #   are self-documenting and survive any future id drift.
    # - Centres with school_id IS NULL (online/foundation/bench) simply have
    #   no rows: there is no roster path for them.
    execute(
      """
      CREATE VIEW centre_students AS
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
      """,
      "DROP VIEW centre_students"
    )
  end
end
