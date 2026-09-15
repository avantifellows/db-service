-- Parameters: $1 exclusive enrollment ID cursor; $2 page size (1..500).
-- Rank ALL audit history before pagination. No student names/contact/identifiers.
-- Audit IDs are parsed only after positive-integer/range checks; malformed
-- operations remain linked to every valid exact target they contain.
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
), incomplete_history AS MATERIALIZED (
  SELECT d.id AS audit_id, d.user_id, d.student_id
  FROM audited_dropouts d
  WHERE d.operation_is_valid IS NOT TRUE
  UNION ALL
  SELECT u.id AS audit_id,
    u.affected_identifiers ->> 'user_id' AS user_id,
    u.affected_identifiers ->> 'student_pk_id' AS student_id
  FROM relevant_audits u
  LEFT JOIN relevant_audits d
    ON u.action = 'student_program_dropout_undo'
   AND d.action = 'student_program_dropout'
   AND d.id::text = u.affected_identifiers ->> 'dropout_audit_id'
  WHERE u.action = 'student_program_dropout_undo' AND d.id IS NULL
), targets AS (
  SELECT d.*, d.batch_enrollment_id AS enrollment_id, 'batch' AS kind
  FROM audited_dropouts d
  WHERE d.batch_enrollment_id IS NOT NULL
  UNION ALL
  SELECT d.*, g.enrollment_id, 'global' AS kind
  FROM audited_dropouts d
  JOIN global_item_ids g ON g.id = d.id
  WHERE g.enrollment_id IS NOT NULL
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
), events AS (
  SELECT t.enrollment_id, t.kind,
    t.id AS dropout_audit_id, t.id AS evidence_audit_id,
    t.inserted_at AS proposed_updated_at,
    t.user_id, t.student_id, t.batch_id::text AS batch_id,
    false AS expected_current, t.dropout_date_raw AS expected_end_date,
    t.operation_is_valid AS operation_is_valid,
    true AS valid_link
  FROM targets t
  UNION ALL
  SELECT t.enrollment_id, t.kind, t.id, u.undo_audit_id, u.inserted_at,
    t.user_id, t.student_id, t.batch_id::text, true, NULL,
    t.operation_is_valid,
    u.undo_user_id IS NOT NULL
      AND u.undo_student_id IS NOT NULL
      AND u.undo_user_id = t.user_id
      AND u.undo_student_id = t.student_id
      AND u.inserted_at >= t.inserted_at
      AND u.undo_link_count = 1 AS valid_link
  FROM targets t
  JOIN undo_links u ON u.dropout_audit_id = t.id
  UNION ALL
  SELECT d.status_enrollment_id, 'status', d.id, u.undo_audit_id, u.inserted_at,
    d.user_id, d.student_id, NULL, false, u.inserted_at::date::text,
    d.operation_is_valid,
    u.undo_user_id IS NOT NULL
      AND u.undo_student_id IS NOT NULL
      AND u.undo_user_id = d.user_id
      AND u.undo_student_id = d.student_id
      AND u.inserted_at >= d.inserted_at
      AND u.undo_link_count = 1 AS valid_link
  FROM audited_dropouts d
  JOIN undo_links u ON u.dropout_audit_id = d.id
  WHERE d.status_enrollment_id IS NOT NULL
), event_counts AS (
  SELECT e.*,
    count(*) OVER (PARTITION BY e.enrollment_id, e.evidence_audit_id) AS duplicate_targets
  FROM events e
), history_checks AS MATERIALIZED (
  SELECT enrollment_id,
    bool_and(operation_is_valid IS TRUE) AS all_operations_valid,
    bool_and(valid_link IS TRUE) AS all_links_valid,
    bool_and(duplicate_targets = 1) AS all_targets_unique,
    count(*) AS event_count
  FROM event_counts
  GROUP BY enrollment_id
), immutable_checks AS MATERIALIZED (
  SELECT h.enrollment_id,
    bool_and(
      h.user_id IS NOT NULL
        AND h.student_id IS NOT NULL
        AND e.id IS NOT NULL
        AND h.user_id IS NOT DISTINCT FROM e.user_id::text
        AND s.id IS NOT NULL
    ) AS all_identity_consistent,
    bool_and(
      h.kind IS DISTINCT FROM 'batch'
        OR (
          e.group_type IS NOT DISTINCT FROM 'batch'
          AND e.group_id::text IS NOT DISTINCT FROM h.batch_id
        )
    ) AS all_group_consistent,
    bool_and(e.inserted_at <= h.proposed_updated_at) AS all_creation_consistent
  FROM event_counts h
  LEFT JOIN enrollment_record e ON e.id = h.enrollment_id
  LEFT JOIN student s
    ON s.id::text = h.student_id
   AND s.user_id = e.user_id
  GROUP BY h.enrollment_id
), ranked AS (
  SELECT e.*, h.all_operations_valid, h.all_links_valid, h.all_targets_unique,
    h.event_count, i.all_identity_consistent, i.all_group_consistent,
    i.all_creation_consistent,
    row_number() OVER (
      PARTITION BY e.enrollment_id
      ORDER BY e.proposed_updated_at DESC, e.evidence_audit_id DESC
    ) AS rank
  FROM event_counts e
  JOIN history_checks h ON h.enrollment_id = e.enrollment_id
  JOIN immutable_checks i ON i.enrollment_id = e.enrollment_id
)
SELECT r.enrollment_id, r.dropout_audit_id, r.evidence_audit_id, r.proposed_updated_at,
  r.student_id, r.event_count, to_jsonb(e) AS before,
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM incomplete_history h
      WHERE h.user_id = r.user_id OR h.student_id = r.student_id
    ) THEN 'unresolved_incomplete_audit_history'
    WHEN r.all_operations_valid IS NOT TRUE
      THEN 'unresolved_incomplete_audit_history'
    WHEN e.id IS NULL THEN 'unresolved_missing_enrollment'
    WHEN r.all_links_valid IS NOT TRUE OR r.all_targets_unique IS NOT TRUE
      THEN 'unresolved_audit_link'
    WHEN r.all_identity_consistent IS NOT TRUE THEN 'unresolved_identity'
    WHEN r.all_creation_consistent IS NOT TRUE THEN 'unresolved_creation_time'
    WHEN r.all_group_consistent IS NOT TRUE THEN 'unresolved_group'
    WHEN e.is_current IS DISTINCT FROM r.expected_current
      OR e.end_date::text IS DISTINCT FROM r.expected_end_date
      THEN 'unresolved_state'
    WHEN e.updated_at IS NULL THEN 'unresolved_missing_timestamp'
    WHEN e.updated_at >= r.proposed_updated_at
      THEN 'preserve_equal_or_later'
    ELSE 'proposed'
  END AS disposition
FROM ranked r
LEFT JOIN enrollment_record e ON e.id = r.enrollment_id
WHERE r.rank = 1 AND r.enrollment_id > $1
ORDER BY r.enrollment_id LIMIT LEAST(GREATEST($2, 1), 500)
