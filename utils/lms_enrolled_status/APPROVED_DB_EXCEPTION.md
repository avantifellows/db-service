# Approved one-Student DB-evidence exception — local only

The user approved using the corroborating DB dates for Student
**20272025066071** after reviewing the missing-audit finding. This exception is
not permission to infer history for other Students, and not a production apply
approval. Proposal reference: Discord message1550057659800101004, followed by
user confirmation, “Yeah it's okay for this 1 student”.

`approved_db_exception.py` is restricted to internal Student500583, User511050,
the external ID above, creation audit175, original Batch/Grade enrollment IDs
2823096/2823097, and current dropout enrollment2947084. Changed identities,
dates, extra history, or newly available dropout audit evidence fail closed.
It uses the same local-only connection guard and reviewed-manifest safeguards
as the other utilities.

Add one non-current enrolled status period **July22→July27,2026**. Preserve
Student.status=dropout, the current dropout row, School/Batch/Grade/Auth Group
memberships, and all existing timestamps. The new row uses actual repair-time
inserted_at/updated_at. Add one repair audit identifying the evidence source as
creation audit plus corroborating DB dates and the explicit user-approved
exception. Its dropout_audit_id is **null**: no original event is fabricated.

```sh
python utils/lms_enrolled_status/approved_db_exception.py \
  --database dbservice_status_repair_exception_20260917 \
  --output /private/tmp/exception-report.json
shasum -a 256 /private/tmp/exception-report.json
# Review the report, then use its exact hash:
python utils/lms_enrolled_status/approved_db_exception.py \
  --database dbservice_status_repair_exception_20260917 \
  --apply /private/tmp/exception-report.json --approve-sha256 REVIEWED_SHA256 \
  --actor YOUR_EMAIL --output /private/tmp/exception-result.json
```

The one-Student manifest binds the database, script and imported initial helper.
Any changed evidence aborts the transaction. An unchanged rerun returns
already_applied without adding another row/audit. Output files are private and
exclusive-create; verify command success and a fresh report rather than treating
an output file alone as proof of commit. Never use a remote DB tunnel.

September17 local rehearsal:1 new ended enrolled period +1 repair audit;
repeat apply unchanged; all original table rows match the untouched snapshot.
The remaining-cases report recognizes this completed approved exception and
no longer counts it as an outstanding manual-review case. Other missing-audit
Students remain report-only.

Run tests: `python -m unittest discover -s utils/lms_enrolled_status -v`.
