-- Unresolvable audit shapes and orphan undos, without personal data.
WITH relevant_audits AS MATERIALIZED (
  SELECT id, action, inserted_at, affected_identifiers, changed_values
  FROM lms_student_write_audits
  WHERE action IN ('student_program_dropout', 'student_program_dropout_undo')
)
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
ORDER BY a.id
