-- Unresolvable audit shapes and orphan undos, without personal data.
-- Keep operation shape/date/status validation in sync with report.sql.
WITH relevant_audits AS MATERIALIZED (
  SELECT id, action, inserted_at, affected_identifiers, changed_values
  FROM lms_student_write_audits
  WHERE action IN ('student_program_dropout', 'student_program_dropout_undo')
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
    count(*) OVER (PARTITION BY d.id) AS undo_link_count
  FROM relevant_audits u
  JOIN relevant_audits d
    ON u.action = 'student_program_dropout_undo'
   AND d.action = 'student_program_dropout'
   AND d.id::text = u.affected_identifiers ->> 'dropout_audit_id'
), audit_issues AS (
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
