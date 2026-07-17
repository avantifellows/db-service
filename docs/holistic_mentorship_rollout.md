# Holistic Mentorship Rollout

## Active deployment path

As of 2026-07-16, staging deploys through ECS Fargate with
`.github/workflows/staging_deploy_ecs.yml`; the former staging EC2 workflow is
disabled. Production still deploys the `release` branch to EC2 through
`.github/workflows/production_deploy.yml`. The production ECS workflow is
manual validation only until its documented cutover.

Use the active workflow for each environment. Do not use the standalone legacy
staging migration workflow for this rollout.

## Release order

1. Configure different `BEARER_TOKEN` values in staging and production. Verify
   that each environment rejects the other environment's token with `401`.
2. Deploy db-service to staging. Its active ECS workflow runs the additive
   migrations before replacing the service.
3. Complete every staging smoke check below.
4. Merge and deploy db-service from `release` to production. Confirm migrations,
   liveness, readiness, and authentication before enabling callers.
5. Deploy and enable `etl-next` Profile generation.
6. Deploy `af_lms` Holistic Mentorship workflows.

Never run a down migration after Holistic Mentorship tables contain data.
The privacy deletion migration is also additive: its one-per-Student tombstone
and content guards must remain in place across application rollback so erased
Profile or Notes content cannot be recreated.

## Staging smoke checks

Use only deterministic staging fixtures. Do not use production credentials,
source records, questionnaire answers, prompt content, or summaries.

```bash
export BASE_URL=https://staging-db.avantifellows.org
export BEARER_TOKEN='<staging token from the approved secret store>'

test "$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/health")" = 200
test "$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/health/ready")" = 200
test "$(curl -sS -o /dev/null -w '%{http_code}' \
  -H 'Authorization: Bearer invalid-smoke-token' \
  "$BASE_URL/api/holistic-mentorship/profile-preflight")" = 401
```

Register and explicitly activate a disposable configuration. `abc` and its
published SHA-256 value are test-only constants.

```bash
export SMOKE_ID="staging-smoke-$(date +%s)"

CONFIG_ID=$(curl -fsS -X POST \
  -H "Authorization: Bearer $BEARER_TOKEN" -H 'content-type: application/json' \
  "$BASE_URL/api/holistic-mentorship/prompt-configurations" \
  -d "{\"prompt_version\":\"$SMOKE_ID\",\"template_text\":\"abc\",\"template_hash\":\"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\",\"model_id\":\"smoke/test-model\"}" \
  | jq -er '.id')

curl -fsS -X POST -H "Authorization: Bearer $BEARER_TOKEN" \
  -H 'content-type: application/json' \
  "$BASE_URL/api/holistic-mentorship/prompt-configurations/$CONFIG_ID/activate" \
  -d '{}' | jq -e '.state == "active"'
```

Preflight one seeded, eligible, synthetic Grade 11 Student. The approved Grade
11 source is Form `6a44a83d1184e717b920c499` and AF Session
`EnableStudents_6a44a83d1184e717b920c499`. The Grade 12 equivalents are Form
`6a4deca8e030ebe34669fb0f` and AF Session
`EnableStudents_6a4deca8e030ebe34669fb0f`.

```bash
export SOURCE_USER_ID='<synthetic staging user.id>'

PREFLIGHT=$(jq -nc --arg user "$SOURCE_USER_ID" --argjson config "$CONFIG_ID" \
  '{records:[{record_ref:"staging-smoke",source_user_id:$user,source_record_type:"production",form_id:"6a44a83d1184e717b920c499",af_session_id:"EnableStudents_6a44a83d1184e717b920c499",entry_grade:11,answer_fingerprint:"staging-smoke-answers-v1",prompt_configuration_id:$config}]}' \
  | curl -fsS -X POST -H "Authorization: Bearer $BEARER_TOKEN" \
      -H 'content-type: application/json' \
      "$BASE_URL/api/holistic-mentorship/profile-preflight" -d @-)

STUDENT_ID=$(jq -er '.results[0].student_id' <<<"$PREFLIGHT")
REVISION=$(jq -r '.results[0].profile_revision // "null"' <<<"$PREFLIGHT")
```

Queue and start a unique run, then publish exactly five summaries. Confirm the
response and query the staging database for one parent at revision 1 with five
children; that verifies the atomic publication boundary.

```bash
export ETL_RUN_ID="$SMOKE_ID"

status_body() {
  jq -nc --arg run "$ETL_RUN_ID" --arg state "$1" \
    --argjson student "$STUDENT_ID" --argjson config "$CONFIG_ID" \
    '{etl_run_id:$run,student_id:$student,form_id:"6a44a83d1184e717b920c499",af_session_id:"EnableStudents_6a44a83d1184e717b920c499",entry_grade:11,prompt_configuration_id:$config,state:$state}'
}

for state in queued running; do
  status_body "$state" | curl -fsS -X POST \
    -H "Authorization: Bearer $BEARER_TOKEN" -H 'content-type: application/json' \
    "$BASE_URL/api/holistic-mentorship/profile-generation-statuses" -d @- \
    | jq -e --arg state "$state" '.state == $state'
done

jq -nc --arg run "$ETL_RUN_ID" --arg user "$SOURCE_USER_ID" \
  --argjson student "$STUDENT_ID" --argjson config "$CONFIG_ID" \
  --argjson revision "$REVISION" \
  '{etl_run_id:$run,student_id:$student,source_user_id:$user,form_id:"6a44a83d1184e717b920c499",af_session_id:"EnableStudents_6a44a83d1184e717b920c499",entry_grade:11,prompt_configuration_id:$config,schema_fingerprint:"staging-smoke-schema-v1",answer_fingerprint:"staging-smoke-answers-v1",warehouse_loaded_at:"2026-07-16T10:00:00Z",generated_at:"2026-07-16T10:05:00Z",expected_profile_revision:$revision,force:false,summaries:[range(1;6) as $n|{position:$n,question_set_title:("Question Set "+($n|tostring)),summary:("Smoke summary "+($n|tostring))}]}' \
  | curl -fsS -X POST -H "Authorization: Bearer $BEARER_TOKEN" \
      -H 'content-type: application/json' \
      "$BASE_URL/api/holistic-mentorship/profiles/publish" -d @- \
  | jq -e '.result == "published" or .result == "replaced"'

psql "$STAGING_DATABASE_URL" -c \
  "SELECT p.revision, count(s.id) FROM holistic_mentorship_student_profiles p JOIN holistic_mentorship_student_profile_summaries s ON s.student_profile_id=p.id WHERE p.last_successful_etl_run_id='$ETL_RUN_ID' GROUP BY p.id HAVING count(s.id)=5;"
```

Before enabling callers, run the privacy schema and Profile contract tests.
They verify the unique immutable tombstone, guarded content tables, the
`privacy_erased` Preflight result, and normal/forced publication rejection.

```bash
mix test test/dbservice/holistic_mentorship_privacy_schema_test.exs \
  test/dbservice_web/controllers/holistic_mentorship_profile_preflight_controller_test.exs \
  test/dbservice_web/controllers/holistic_mentorship_profile_publish_controller_test.exs \
  test/dbservice_web/controllers/holistic_mentorship_regeneration_request_controller_test.exs
```

For Student cleanup, create one active Mapping for a disposable synthetic
Student, mutate the Student through the normal db-service API, and confirm in
the same staging database that the canonical mutation committed, exactly that
Mapping now has `ended_at`, `end_source = 'db_service_student_eligibility'`,
the expected deterministic `end_reason`, and no replacement Mapping exists.

```bash
curl -fsS -X PUT -H "Authorization: Bearer $BEARER_TOKEN" \
  -H 'content-type: application/json' "$BASE_URL/api/student/$STUDENT_ID" \
  -d '{"status":"dropout"}' | jq -e '.status == "dropout"'

psql "$STAGING_DATABASE_URL" -c \
  "SELECT ended_at IS NOT NULL, end_source, end_reason FROM holistic_mentorship_mentor_mentee_mappings WHERE student_id=$STUDENT_ID ORDER BY started_at DESC LIMIT 1;"
psql "$STAGING_DATABASE_URL" -c \
  "SELECT count(*) FROM holistic_mentorship_mentor_mentee_mappings WHERE student_id=$STUDENT_ID AND ended_at IS NULL;"
```

Verify the sync guard before any production-to-staging refresh:

```bash
mix test test/dbservice/utils/fetch_data_script_test.exs
```

The command-fake test must show `--exclude-table-data=public.holistic_mentorship_*`
for production-to-staging only. Production-to-local must remain available
without that argument, and any production target must fail before `pg_dump` or
`psql` runs.

## Monitoring and reconciliation

Monitor route, duration, HTTP status, correlation metadata, opaque `record_ref`,
opaque request key, ETL run ID, safe state, and safe reason/error code only.
Reconcile counts by those references and codes. Never emit source User IDs,
canonical Student IDs, answers, template text, rendered prompts, summaries, or
request bodies to logs, alerts, dashboards, or tickets.

Alert on readiness failures, authentication failures above the expected probe
baseline, elevated safe rejection/error codes, stuck `queued`/`running` states,
and a production-to-staging sync whose captured `pg_dump` arguments lack the
Holistic wildcard.

## Application rollback

1. Stop new `etl-next` Profile work and disable new `af_lms` Holistic writes.
2. Retain the safe run/request references needed to reconcile in-flight work.
3. Redeploy the prior known-good `af_lms`, `etl-next`, and db-service application
   revisions, in that order where callers must be stopped before db-service.
4. Recheck health, readiness, authentication isolation, and existing Profile
   reads.
5. Preserve all Holistic schema and data. Do not down-migrate populated tables;
   forward-fix the application or apply a new additive migration.
