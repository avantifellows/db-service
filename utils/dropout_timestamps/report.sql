-- Parameters: $1 exclusive enrollment ID cursor; $2 page size (1..500).
-- Rank ALL audit history before pagination. No student names/contact/identifiers.
WITH relevant_audits AS MATERIALIZED (
  SELECT id, action, inserted_at, affected_identifiers, changed_values
  FROM lms_student_write_audits
  WHERE action IN ('student_program_dropout', 'student_program_dropout_undo')
), incomplete_history AS MATERIALIZED (
SELECT a.id AS audit_id, a.action,
  a.affected_identifiers ->> 'user_id' AS user_id,
  a.affected_identifiers ->> 'student_pk_id' AS student_id,
  CASE WHEN a.action = 'student_program_dropout_undo' THEN 'unresolved_undo_without_dropout'
       ELSE 'unresolved_dropout_without_exact_targets' END AS disposition
FROM relevant_audits a
LEFT JOIN relevant_audits d
  ON a.action = 'student_program_dropout_undo' AND d.action = 'student_program_dropout'
    AND d.id::text = a.affected_identifiers ->> 'dropout_audit_id'
WHERE (a.action = 'student_program_dropout' AND (
  jsonb_typeof(a.changed_values #> '{batch_enrollment_id,old}') IS DISTINCT FROM 'number'
  OR COALESCE(a.changed_values #>> '{batch_enrollment_id,old}', '') !~ '^[0-9]{1,18}$'
  OR (a.changed_values ? 'ended_enrollment_ids' AND (
    jsonb_typeof(a.changed_values #> '{ended_enrollment_ids,old}') IS DISTINCT FROM 'array'
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(a.changed_values #> '{ended_enrollment_ids,old}') = 'array'
        THEN a.changed_values #> '{ended_enrollment_ids,old}' ELSE '[]'::jsonb END) item
      WHERE jsonb_typeof(item) IS DISTINCT FROM 'number' OR item::text !~ '^[0-9]{1,18}$')
    OR jsonb_typeof(a.changed_values #> '{dropout_status_enrollment_id,new}') IS DISTINCT FROM 'number'
    OR COALESCE(a.changed_values #>> '{dropout_status_enrollment_id,new}', '') !~ '^[0-9]{1,18}$'
  ))
))
OR (a.action = 'student_program_dropout_undo' AND d.id IS NULL)
), dropouts AS (
  SELECT id, inserted_at, affected_identifiers, changed_values
  FROM relevant_audits WHERE action = 'student_program_dropout'
), targets AS (
  SELECT d.*, t.enrollment_id, t.kind
  FROM dropouts d
  CROSS JOIN LATERAL (
    SELECT d.changed_values #> '{batch_enrollment_id,old}' AS enrollment_id, 'batch' AS kind
    UNION ALL
    SELECT value, 'global' FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(d.changed_values #> '{ended_enrollment_ids,old}') = 'array'
        THEN d.changed_values #> '{ended_enrollment_ids,old}' ELSE '[]'::jsonb END)
  ) t
  WHERE jsonb_typeof(t.enrollment_id) = 'number'
    AND t.enrollment_id::text ~ '^[0-9]{1,18}$'
), events AS (
  SELECT t.enrollment_id::text::bigint AS enrollment_id, t.kind,
    t.id AS dropout_audit_id, t.id AS evidence_audit_id, t.inserted_at AS proposed_updated_at,
    t.affected_identifiers ->> 'user_id' AS user_id,
    t.affected_identifiers ->> 'student_pk_id' AS student_id,
    t.changed_values #>> '{batch_id,old}' AS batch_id,
    false AS expected_current, t.changed_values #>> '{dropout_date,new}' AS expected_end_date,
    true AS valid_link
  FROM targets t
  UNION ALL
  SELECT t.enrollment_id::text::bigint, t.kind, t.id, u.id, u.inserted_at,
    t.affected_identifiers ->> 'user_id', t.affected_identifiers ->> 'student_pk_id',
    t.changed_values #>> '{batch_id,old}', true, NULL,
    u.affected_identifiers ->> 'user_id' = t.affected_identifiers ->> 'user_id'
      AND u.affected_identifiers ->> 'student_pk_id' = t.affected_identifiers ->> 'student_pk_id'
      AND u.inserted_at >= t.inserted_at
  FROM targets t JOIN relevant_audits u
    ON u.action = 'student_program_dropout_undo'
    AND u.affected_identifiers ->> 'dropout_audit_id' = t.id::text
  UNION ALL
  SELECT (d.changed_values #>> '{dropout_status_enrollment_id,new}')::bigint,
    'status', d.id, u.id, u.inserted_at,
    d.affected_identifiers ->> 'user_id', d.affected_identifiers ->> 'student_pk_id', NULL,
    false, u.inserted_at::date::text,
    u.affected_identifiers ->> 'user_id' = d.affected_identifiers ->> 'user_id'
      AND u.affected_identifiers ->> 'student_pk_id' = d.affected_identifiers ->> 'student_pk_id'
      AND u.inserted_at >= d.inserted_at
  FROM dropouts d JOIN relevant_audits u
    ON u.action = 'student_program_dropout_undo'
    AND u.affected_identifiers ->> 'dropout_audit_id' = d.id::text
  WHERE jsonb_typeof(d.changed_values #> '{dropout_status_enrollment_id,new}') = 'number'
    AND d.changed_values #>> '{dropout_status_enrollment_id,new}' ~ '^[0-9]{1,18}$'
), event_counts AS (
  SELECT *, count(*) OVER (PARTITION BY enrollment_id, evidence_audit_id) AS duplicate_targets
  FROM events
), ranked AS (
  SELECT *, row_number() OVER (PARTITION BY enrollment_id ORDER BY proposed_updated_at DESC, evidence_audit_id DESC) AS rank,
    bool_and(duplicate_targets = 1) OVER (PARTITION BY enrollment_id) AS all_targets_unique,
    bool_and(valid_link IS TRUE) OVER (PARTITION BY enrollment_id) AS all_links_valid,
    count(*) OVER (PARTITION BY enrollment_id) AS event_count
  FROM event_counts
)
SELECT r.enrollment_id, r.dropout_audit_id, r.evidence_audit_id, r.proposed_updated_at,
  r.student_id, r.event_count, to_jsonb(e) AS before,
  CASE
    WHEN EXISTS (SELECT 1 FROM incomplete_history h WHERE h.user_id = r.user_id OR h.student_id = r.student_id)
      THEN 'unresolved_incomplete_audit_history'
    WHEN e.id IS NULL THEN 'unresolved_missing_enrollment'
    WHEN r.all_links_valid IS NOT TRUE OR r.all_targets_unique IS NOT TRUE THEN 'unresolved_audit_link'
    WHEN e.user_id::text IS DISTINCT FROM r.user_id OR NOT EXISTS (
      SELECT 1 FROM student s WHERE s.id::text = r.student_id AND s.user_id = e.user_id
    ) THEN 'unresolved_identity'
    WHEN e.inserted_at > r.proposed_updated_at THEN 'unresolved_creation_time'
    WHEN (r.kind = 'batch' AND (e.group_type <> 'batch' OR e.group_id::text IS DISTINCT FROM r.batch_id))
      OR (r.kind = 'status' AND (e.group_type <> 'status' OR NOT EXISTS (
        SELECT 1 FROM status s WHERE s.id = e.group_id AND s.title::text = 'dropout'
      ))) THEN 'unresolved_group'
    WHEN e.is_current IS DISTINCT FROM r.expected_current
      OR e.end_date::text IS DISTINCT FROM r.expected_end_date THEN 'unresolved_state'
    WHEN e.updated_at IS NULL THEN 'unresolved_missing_timestamp'
    WHEN e.updated_at >= r.proposed_updated_at THEN 'preserve_equal_or_later'
    ELSE 'proposed'
  END AS disposition
FROM ranked r LEFT JOIN enrollment_record e ON e.id = r.enrollment_id
WHERE r.rank = 1 AND r.enrollment_id > $1
ORDER BY r.enrollment_id LIMIT LEAST(GREATEST($2, 1), 500)
