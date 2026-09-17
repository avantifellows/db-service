-- Unresolvable audit shapes and orphan undos, without personal data.
-- Keep operation shape/date/status validation in sync with report.sql.
WITH -- Only a fully matched, later correction can supersede the old status shape.
-- The correction preserves the original row identity and logs its before/after.
correction_values AS MATERIALIZED (
  SELECT a.id, a.inserted_at, a.affected_identifiers, a.created_values,
    a.affected_identifiers->>'user_id' AS user_id,
    a.affected_identifiers->>'student_pk_id' AS student_id,
    CASE WHEN jsonb_typeof(a.changed_values #> '{status_enrollment,old}')='object'
      THEN a.changed_values #> '{status_enrollment,old}' END AS old_row,
    CASE WHEN jsonb_typeof(a.changed_values #> '{status_enrollment,new}')='object'
      THEN a.changed_values #> '{status_enrollment,new}' END AS new_row,
    CASE WHEN jsonb_typeof(a.created_values->'status_enrollment_id')='number'
      AND a.created_values->>'status_enrollment_id' ~ '^[1-9][0-9]{0,17}$'
      THEN (a.created_values->>'status_enrollment_id')::bigint END AS enrollment_id
  FROM lms_student_write_audits a
  WHERE a.action='student_accidental_dropout_correction'
), correction_checks AS MATERIALIZED (
  SELECT c.*,
    COALESCE(
      count(*) OVER (PARTITION BY c.enrollment_id)=1
      AND c.created_values->>'repair_version'='1'
      AND e.id IS NOT NULL AND e.group_type='status'
      AND e.user_id::text=c.user_id AND s.user_id=e.user_id
      AND c.old_row->>'id'=e.id::text
      AND c.old_row->>'group_type'='status'
      AND c.old_row->'is_current'='false'::jsonb
      AND c.new_row->'is_current'='true'::jsonb
      AND c.new_row->'end_date'='null'::jsonb
      AND c.old_row->>'academic_year'='2026-2027'
      AND c.old_row->>'group_id'=ds.id::text AND ds.title='dropout'
      AND e.group_id=es.id AND es.title='enrolled'
      AND (c.old_row - ARRAY['group_id','is_current','start_date','end_date','updated_at'])
        = (c.new_row - ARRAY['group_id','is_current','start_date','end_date','updated_at'])
      AND (to_jsonb(e) - ARRAY['inserted_at','updated_at'])
        = (c.new_row - ARRAY['inserted_at','updated_at'])
      AND rtrim(regexp_replace(replace(c.new_row->>'inserted_at','T',' '), '(\.[0-9]*?)0+$', '\1'), '.')=e.inserted_at::text
      AND rtrim(regexp_replace(replace(c.new_row->>'updated_at','T',' '), '(\.[0-9]*?)0+$', '\1'), '.')=e.updated_at::text
      AND e.updated_at=c.inserted_at
      AND c.inserted_at >= u.inserted_at AND u.inserted_at >= d.inserted_at
      AND e.inserted_at <= d.inserted_at
      AND c.old_row->>'start_date'=d.changed_values #>> '{dropout_date,new}'
      AND c.old_row->>'end_date'=u.inserted_at::date::text
      AND c.new_row->>'start_date' <= c.old_row->>'start_date'
      AND d.changed_values #>> '{dropout_status_enrollment_id,new}'=e.id::text
      AND u.affected_identifiers->>'dropout_audit_id'=d.id::text
      AND d.affected_identifiers->>'user_id'=c.user_id
      AND d.affected_identifiers->>'student_pk_id'=c.student_id
      AND u.affected_identifiers->>'user_id'=c.user_id
      AND u.affected_identifiers->>'student_pk_id'=c.student_id
      AND origin.affected_identifiers->>'user_id'=c.user_id
      AND origin.affected_identifiers->>'student_pk_id'=c.student_id
      AND origin.created_values->>'status'='enrolled'
      AND origin.inserted_at <= d.inserted_at,
      false) AS correction_is_valid
  FROM correction_values c
  LEFT JOIN enrollment_record e ON e.id=c.enrollment_id
  LEFT JOIN student s ON s.id::text=c.student_id
  LEFT JOIN status ds ON ds.id::text=c.old_row->>'group_id'
  LEFT JOIN status es ON es.id=e.group_id
  LEFT JOIN lms_student_write_audits d ON d.id::text=c.created_values->>'dropout_audit_id'
    AND d.action='student_program_dropout'
  LEFT JOIN lms_student_write_audits u ON u.id::text=c.created_values->>'undo_audit_id'
    AND u.action='student_program_dropout_undo'
  LEFT JOIN lms_student_write_audits origin ON origin.id::text=c.created_values->>'source_creation_audit_id'
    AND origin.action='student_bulk_create'
),
 relevant_audits AS MATERIALIZED (
  SELECT id, action, inserted_at, affected_identifiers, changed_values
  FROM lms_student_write_audits
  WHERE action IN ('student_program_dropout', 'student_program_dropout_undo')
), undo_values AS MATERIALIZED (
  SELECT u.*,
    u.changed_values #> '{retained_status_enrollment_ids,old}' AS retained_status_ids,
    CASE
      WHEN NOT (u.changed_values ? 'retained_status_enrollment_ids') THEN true
      WHEN jsonb_typeof(u.changed_values #> '{retained_status_enrollment_ids,old}') IS DISTINCT FROM 'array'
        OR (u.changed_values #> '{retained_status_enrollment_ids,new}') IS DISTINCT FROM
          (u.changed_values #> '{retained_status_enrollment_ids,old}') THEN false
      ELSE NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(u.changed_values #> '{retained_status_enrollment_ids,old}') item
        LEFT JOIN enrollment_record e ON e.id = CASE WHEN jsonb_typeof(item) = 'number'
          AND item::text ~ '^[1-9][0-9]{0,17}$' THEN item::text::bigint END
        WHERE jsonb_typeof(item) IS DISTINCT FROM 'number'
          OR item::text !~ '^[1-9][0-9]{0,17}$'
          OR e.id IS NULL OR e.group_type IS DISTINCT FROM 'status'
          OR e.user_id::text IS DISTINCT FROM d.affected_identifiers ->> 'user_id'
          OR COALESCE(d.changed_values #> '{ended_enrollment_ids,old}' @> jsonb_build_array(item), false) IS NOT TRUE
      ) AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(u.changed_values #> '{retained_status_enrollment_ids,old}') item
        GROUP BY item HAVING count(*) > 1
      ) AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(d.changed_values #> '{ended_enrollment_ids,old}') = 'array'
            THEN d.changed_values #> '{ended_enrollment_ids,old}' ELSE '[]'::jsonb END) item
        JOIN enrollment_record e ON e.id = CASE WHEN jsonb_typeof(item) = 'number'
          AND item::text ~ '^[1-9][0-9]{0,17}$' THEN item::text::bigint END
        WHERE e.group_type = 'status'
          AND NOT (u.changed_values #> '{retained_status_enrollment_ids,old}' @> jsonb_build_array(e.id))
      )
    END AS retained_status_ids_valid
  FROM relevant_audits u
  LEFT JOIN relevant_audits d ON d.action = 'student_program_dropout'
    AND d.id::text = u.affected_identifiers ->> 'dropout_audit_id'
  WHERE u.action = 'student_program_dropout_undo'
), dropout_values AS MATERIALIZED (
  SELECT d.id, d.inserted_at, d.affected_identifiers, d.changed_values,
    d.affected_identifiers ->> 'user_id' AS user_id,
    d.affected_identifiers ->> 'student_pk_id' AS student_id,
    d.changed_values #> '{batch_enrollment_id,old}' AS batch_enrollment_json,
    d.changed_values #>> '{batch_enrollment_id,old}' AS batch_enrollment_raw,
    d.changed_values #> '{batch_id,old}' AS batch_id_json,
    d.changed_values #>> '{batch_id,old}' AS batch_id_raw,
    d.changed_values #> '{ended_enrollment_ids,old}' AS ended_enrollment_json,
    d.changed_values #> '{dropout_status_enrollment_id,new}' AS status_enrollment_json,
    d.changed_values #>> '{dropout_status_enrollment_id,new}' AS status_enrollment_raw,
    d.changed_values #> '{dropout_date,new}' AS dropout_date_json,
    d.changed_values #>> '{dropout_date,new}' AS dropout_date_raw,
    d.changed_values ? 'ended_enrollment_ids' AS has_ended_enrollment_ids,
    d.changed_values ? 'dropout_status_enrollment_id' AS has_status_enrollment_id
  FROM relevant_audits d
  WHERE d.action = 'student_program_dropout'
), dropout_ids AS MATERIALIZED (
  SELECT d.*,
    CASE
      WHEN jsonb_typeof(d.batch_enrollment_json) = 'number'
        AND d.batch_enrollment_raw ~ '^[1-9][0-9]{0,17}$'
        THEN d.batch_enrollment_raw::bigint
    END AS batch_enrollment_id,
    CASE
      WHEN jsonb_typeof(d.batch_id_json) = 'number'
        AND d.batch_id_raw ~ '^[1-9][0-9]{0,17}$'
        THEN d.batch_id_raw::bigint
    END AS batch_id,
    CASE
      WHEN jsonb_typeof(d.status_enrollment_json) = 'number'
        AND d.status_enrollment_raw ~ '^[1-9][0-9]{0,17}$'
        THEN d.status_enrollment_raw::bigint
    END AS status_enrollment_id,
    CASE
      WHEN jsonb_typeof(d.affected_identifiers -> 'user_id') = 'number'
        AND d.user_id ~ '^[1-9][0-9]{0,17}$'
        THEN d.user_id::bigint
    END AS user_id_number,
    CASE
      WHEN jsonb_typeof(d.affected_identifiers -> 'student_pk_id') = 'number'
        AND d.student_id ~ '^[1-9][0-9]{0,17}$'
        THEN d.student_id::bigint
    END AS student_id_number
  FROM dropout_values d
), global_items AS MATERIALIZED (
  SELECT d.id, item, item::text AS target_raw
  FROM dropout_ids d
  CROSS JOIN LATERAL jsonb_array_elements(
    CASE WHEN jsonb_typeof(d.ended_enrollment_json) = 'array'
      THEN d.ended_enrollment_json ELSE '[]'::jsonb END
  ) item
), global_item_ids AS MATERIALIZED (
  SELECT g.id, g.item,
    CASE
      WHEN jsonb_typeof(g.item) = 'number'
        AND g.target_raw ~ '^[1-9][0-9]{0,17}$'
        THEN g.target_raw::bigint
    END AS enrollment_id
  FROM global_items g
), global_item_checks AS MATERIALIZED (
  SELECT d.id,
    jsonb_typeof(d.ended_enrollment_json) = 'array' AS ended_ids_are_array,
    COALESCE(
      bool_and(i.enrollment_id IS NOT NULL) FILTER (WHERE i.id IS NOT NULL),
      true
    ) AS ended_ids_are_valid
  FROM dropout_ids d
  LEFT JOIN global_item_ids i ON i.id = d.id
  GROUP BY d.id, d.ended_enrollment_json
), dropout_dates AS MATERIALIZED (
  SELECT d.*,
    COALESCE(
      CASE
        WHEN jsonb_typeof(d.dropout_date_json) = 'string'
          AND d.dropout_date_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
          CASE
            WHEN substring(d.dropout_date_raw, 1, 4)::integer BETWEEN 1 AND 9999
              AND substring(d.dropout_date_raw, 6, 2)::integer BETWEEN 1 AND 12
              AND substring(d.dropout_date_raw, 9, 2)::integer BETWEEN 1 AND 31
            THEN CASE
              WHEN extract(
                month FROM make_date(
                  substring(d.dropout_date_raw, 1, 4)::integer,
                  substring(d.dropout_date_raw, 6, 2)::integer,
                  1
                ) + substring(d.dropout_date_raw, 9, 2)::integer - 1
              ) = substring(d.dropout_date_raw, 6, 2)::integer
              THEN true
              ELSE false
            END
            ELSE false
          END
        ELSE false
      END,
      false
    ) AS dropout_date_is_valid
  FROM dropout_ids d
), dropout_shapes AS MATERIALIZED (
  SELECT d.*, g.ended_ids_are_array, g.ended_ids_are_valid,
    CASE
      WHEN NOT d.has_ended_enrollment_ids AND NOT d.has_status_enrollment_id
        THEN true
      WHEN d.has_ended_enrollment_ids AND d.has_status_enrollment_id
        AND g.ended_ids_are_array
        AND g.ended_ids_are_valid
        AND d.status_enrollment_id IS NOT NULL
        THEN true
      ELSE false
    END AS global_shape_is_valid
  FROM dropout_dates d
  JOIN global_item_checks g ON g.id = d.id
), dropouts AS MATERIALIZED (
  SELECT d.*,
    CASE
      WHEN d.user_id_number IS NULL OR d.student_id_number IS NULL THEN false
      ELSE EXISTS (
        SELECT 1
        FROM student audit_student
        WHERE audit_student.id = d.student_id_number
          AND audit_student.user_id = d.user_id_number
      )
    END AS owner_evidence_is_valid,
    CASE
      WHEN d.batch_enrollment_id IS NULL OR d.batch_id IS NULL THEN false
      WHEN EXISTS (
        SELECT 1
        FROM enrollment_record batch_enrollment
        WHERE batch_enrollment.id = d.batch_enrollment_id
      ) THEN EXISTS (
        SELECT 1
        FROM enrollment_record batch_enrollment
        WHERE batch_enrollment.id = d.batch_enrollment_id
          AND batch_enrollment.user_id::text IS NOT DISTINCT FROM d.user_id
          AND batch_enrollment.group_type = 'batch'
          AND batch_enrollment.group_id = d.batch_id
      )
      ELSE true
    END AS batch_evidence_is_valid,
    CASE
      WHEN d.global_shape_is_valid AND d.has_ended_enrollment_ids THEN
        EXISTS (
          SELECT 1
          FROM enrollment_record status_enrollment
          JOIN status dropout_status
            ON dropout_status.id = status_enrollment.group_id
           AND dropout_status.title::text = 'dropout'
          WHERE status_enrollment.id = d.status_enrollment_id
            AND status_enrollment.user_id::text IS NOT DISTINCT FROM d.user_id
            AND status_enrollment.group_type = 'status'
            AND status_enrollment.inserted_at <= d.inserted_at
        ) OR EXISTS (
          SELECT 1 FROM correction_checks c
          WHERE c.correction_is_valid AND c.enrollment_id=d.status_enrollment_id
            AND c.created_values->>'dropout_audit_id'=d.id::text
            AND c.user_id=d.user_id AND c.student_id=d.student_id
        )
      ELSE NOT d.has_ended_enrollment_ids AND NOT d.has_status_enrollment_id
    END AS status_evidence_is_valid
  FROM dropout_shapes d
), audited_dropouts AS MATERIALIZED (
  SELECT d.*,
    d.user_id_number IS NOT NULL
      AND d.student_id_number IS NOT NULL
      AND d.owner_evidence_is_valid
      AND d.batch_enrollment_id IS NOT NULL
      AND d.batch_id IS NOT NULL
      AND d.batch_evidence_is_valid
      AND d.dropout_date_is_valid
      AND d.global_shape_is_valid
      AND d.status_evidence_is_valid AS operation_is_valid
  FROM dropouts d
), undo_links AS MATERIALIZED (
  SELECT u.id AS undo_audit_id, d.id AS dropout_audit_id,
    u.inserted_at, u.affected_identifiers ->> 'user_id' AS undo_user_id,
    u.affected_identifiers ->> 'student_pk_id' AS undo_student_id,
    u.retained_status_ids, u.retained_status_ids_valid,
    count(*) OVER (PARTITION BY d.id) AS undo_link_count
  FROM undo_values u
  JOIN relevant_audits d
    ON u.action = 'student_program_dropout_undo'
   AND d.action = 'student_program_dropout'
   AND d.id::text = u.affected_identifiers ->> 'dropout_audit_id'
), audit_issues AS (
  SELECT c.id AS audit_id, 'student_accidental_dropout_correction' AS action,
    c.user_id, c.student_id, 'unresolved_status_correction' AS disposition
  FROM correction_checks c WHERE NOT c.correction_is_valid
  UNION ALL
  SELECT d.id AS audit_id, 'student_program_dropout' AS action,
    d.user_id, d.student_id,
    'unresolved_dropout_without_exact_targets' AS disposition
  FROM audited_dropouts d
  WHERE d.operation_is_valid IS NOT TRUE
  UNION ALL
  SELECT u.id AS audit_id, u.action,
    u.affected_identifiers ->> 'user_id' AS user_id,
    u.affected_identifiers ->> 'student_pk_id' AS student_id,
    'unresolved_undo_without_dropout' AS disposition
  FROM relevant_audits u
  LEFT JOIN relevant_audits d
    ON u.action = 'student_program_dropout_undo'
   AND d.action = 'student_program_dropout'
   AND d.id::text = u.affected_identifiers ->> 'dropout_audit_id'
  WHERE u.action = 'student_program_dropout_undo' AND d.id IS NULL
  UNION ALL
  SELECT DISTINCT d.id AS audit_id, 'student_program_dropout' AS action,
    d.user_id, d.student_id,
    'unresolved_duplicate_undo_link' AS disposition
  FROM audited_dropouts d
  JOIN undo_links u ON u.dropout_audit_id = d.id
  WHERE u.undo_link_count > 1
), invalid_undo_links AS (
  SELECT u.undo_audit_id AS audit_id, 'student_program_dropout_undo' AS action,
    u.undo_user_id AS user_id, u.undo_student_id AS student_id,
    'unresolved_invalid_undo_link' AS disposition
  FROM undo_links u
  JOIN relevant_audits d ON d.id = u.dropout_audit_id
  WHERE u.undo_link_count > 1
    OR u.retained_status_ids_valid IS NOT TRUE
    OR u.undo_user_id IS NULL
    OR u.undo_student_id IS NULL
    OR u.undo_user_id IS DISTINCT FROM d.affected_identifiers ->> 'user_id'
    OR u.undo_student_id IS DISTINCT FROM d.affected_identifiers ->> 'student_pk_id'
    OR u.inserted_at < d.inserted_at
)
SELECT audit_id, action, user_id, student_id, disposition
FROM audit_issues
UNION ALL
SELECT audit_id, action, user_id, student_id, disposition
FROM invalid_undo_links
ORDER BY audit_id
