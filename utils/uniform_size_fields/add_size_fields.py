#!/usr/bin/env python3
"""Append the t-shirt / track pant size dropdowns to existing form schemas.

Live form schemas are rows in `form_schema`, not code, so the seed file only
covers a fresh database. This adds the two dropdown fields to the schemas you
name, through the API, so the write goes through the usual changeset.

Note the live `attributes` shape: an object keyed by the field's position
("0", "1", "2", ...), not a list, and `required` is the string "TRUE"/"false".
Every one of our form_schema rows is stored this way, so that is what this
writes - do not follow the `"fields" => [...]` shape in
priv/repo/seeds/form_schemas.exs, which no live row uses.

Read-only by default: without --apply it prints what each schema would gain.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

SIZES = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"]

HELP_TEXT = {
    "en": "Sizes run smallest (XXS) to largest (XXXL)",
    "hi": "साइज़ सबसे छोटे (XXS) से सबसे बड़े (XXXL) तक हैं",
}

LABELS = {
    "tshirt_size": {"en": "T-shirt size", "hi": "टी-शर्ट का साइज़"},
    "track_pant_size": {"en": "Track pant size", "hi": "ट्रैक पैंट का साइज़"},
}


def size_field(key, required):
    options = [{"label": size, "value": size} for size in SIZES]
    return {
        "key": key,
        "type": "dropdown",
        "label": LABELS[key],
        # Same list in both languages: sizes are written in Latin letters either way.
        "options": {"en": options, "hi": options},
        "helpText": HELP_TEXT,
        "required": "TRUE" if required else "false",
        "dependant": "",
        "showBasedOn": "",
        "dependantField": "",
        "multipleSelect": "",
        "showBasedOnCondition": "",
    }


def request(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token)
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        sys.exit("%s %s failed: %s %s" % (method, url, error.code, error.read().decode()[:400]))


def existing_keys(attributes):
    return {field.get("key") for field in attributes.values() if isinstance(field, dict)}


def next_index(attributes):
    indexes = [int(key) for key in attributes if key.isdigit()]
    return max(indexes) + 1 if indexes else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://localhost:4000")
    parser.add_argument("--form-schema-id", type=int, nargs="+", required=True,
                        help="ids from GET /api/form-schema")
    parser.add_argument("--optional", action="store_true",
                        help="add the fields as required=false (default is required=TRUE, "
                             "matching the other fields on these forms)")
    parser.add_argument("--apply", action="store_true", help="perform the PATCH")
    args = parser.parse_args()

    token = os.environ.get("BEARER_TOKEN")
    if not token:
        sys.exit("BEARER_TOKEN is not set")

    for schema_id in args.form_schema_id:
        url = "%s/api/form-schema/%s" % (args.base_url, schema_id)
        schema = request("GET", url, token)
        name = schema.get("name")
        attributes = dict(schema.get("attributes") or {})

        if "fields" in attributes:
            sys.exit("%s (%s): unexpected list-shaped attributes, refusing to guess" %
                     (schema_id, name))

        present = existing_keys(attributes)
        additions = [key for key in LABELS if key not in present]

        if not additions:
            print("%s (%s): already has both size fields, skipping" % (schema_id, name))
            continue

        if not args.apply:
            print("%s (%s): would add %s at index %s" %
                  (schema_id, name, ", ".join(additions), next_index(attributes)))
            continue

        index = next_index(attributes)
        for key in additions:
            attributes[str(index)] = size_field(key, required=not args.optional)
            index += 1

        # The endpoint replaces `attributes` wholesale, so send the merged map back.
        updated = request("PATCH", url, token, {"attributes": attributes})
        if not set(LABELS) <= existing_keys(updated.get("attributes") or {}):
            sys.exit("%s (%s): PATCH did not persist the size fields" % (schema_id, name))
        print("%s (%s): added %s" % (schema_id, name, ", ".join(additions)))

    if not args.apply:
        print("\nRead-only run. Re-run with --apply to write.")


if __name__ == "__main__":
    main()
