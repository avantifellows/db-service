# Project Context

## Revised NVS student writes

- LMS is the authorization boundary for private NVS student writes; DB Service treats submitted actor metadata as trusted audit context.
- NVS school scope is established by matching school code and UDISE, a current program whose product code is `NVS`, and the student's program enrollment where applicable. Centre and `school.program_ids` are not part of this scope.
- PEN and Grade 10 Roll Number are the NVS creation identifiers. APAAR remains historical and read-only.
- `CBSE` is stored as `CBSE`; `Others` is stored as null. NVS writes store gender `Other`, while legacy input `Others` is accepted.
- NVS batch selection is exact by program, grade, and normalized stream. Missing or ambiguous matches are errors; there is no fallback batch.
- NVS grade/stream edits and program dropout preserve enrollments and batch memberships belonging to other programs.

## Flagged ambiguity

- PEN currently requires 11 digits with a non-zero first digit. Product/Ops confirmation is required before allowing a leading zero.
