# Uniform size form fields

Adds the `tshirt_size` and `track_pant_size` dropdowns to existing form schemas,
so teachers pick a size instead of typing one.

The `student` columns and their validation ship in the application; this utility
only covers the **form** side, because form schemas are rows in `form_schema`
rather than code. `priv/repo/seeds/form_schemas.exs` seeds the two fields into a
fresh database, but it skips any schema that already exists, so every real
environment needs this script.

## The live `attributes` shape

Live rows store `attributes` as an object keyed by the field's position, and
`required` as a string:

```json
{
  "0": { "key": "phone", "type": "phone", "required": "TRUE", ... },
  "1": { "key": "whatsapp_phone", ... }
}
```

All 39 form schemas are stored this way. The `"fields" => [...]` list in
`priv/repo/seeds/form_schemas.exs` matches no live row - do not copy that shape
into a live schema.

## Usage

```bash
export BEARER_TOKEN=...            # same token the API expects

# Which schemas are there, and what are their ids?
curl -H "Authorization: Bearer $BEARER_TOKEN" "$BASE_URL/api/form-schema?limit=100"

# Read-only: prints what each schema would gain, writes nothing.
python3 add_size_fields.py --base-url "$BASE_URL" --form-schema-id 35 21

# Write.
python3 add_size_fields.py --base-url "$BASE_URL" --form-schema-id 35 21 --apply
```

The fields are appended after the schema's existing fields, as `required: "TRUE"`
to match the other fields on these forms. Pass `--optional` to add them as
`required: "false"` instead.

Re-running is safe: a schema that already carries a size field is skipped, so a
partial run can just be repeated. Each schema is a separate `PATCH`, so a
failure part way through leaves the schemas already updated in place and stops.

## Values

`XXS, XS, S, M, L, XL, XXL, XXXL`, smallest to largest, the same list in `en`
and `hi`. This must stay in step with `@valid_uniform_sizes` in
`lib/dbservice/utils/util.ex`, which is what the `student` changeset and the
`student_tshirt_size_check` / `student_track_pant_size_check` constraints enforce.
A value outside that list is rejected on write even if a form offers it.
