# 2026-27 Chapter Name Correction

This folder contains a one-off maintenance script for correcting `chapter.name`
values from the signed-off 2026-27 LMS timemap.

The correction data lives in `chapter_name_updates.json`. Product has confirmed
that the Google Sheet names are the source of truth, and the current DB names in
that file are outdated.

## Files

- `chapter_name_updates.json`: approved correction data.
- `fix_chapter_names.py`: dry-run, apply, and rollback script.
- `backups/`: generated local backup JSON files. Backup files are ignored by git.

## Database Connection

The script uses `DATABASE_URL` when present. Otherwise it uses `PGHOST`,
`PGPORT`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD`, falling back to local
db-service dev defaults:

```bash
PGHOST=localhost
PGPORT=5432
PGDATABASE=dbservice_dev
PGUSER=postgres
PGPASSWORD=postgres
```

Install a Postgres Python driver if needed:

```bash
python -m pip install "psycopg[binary]"
```

`psycopg2-binary` is also supported.

## Dry Run

Dry-run is the default:

```bash
python priv/repo/chapter_name_correction_2026_27/fix_chapter_names.py
```

The script validates that every target `chapter.code` exists exactly once and
that the current DB English chapter name matches `expected_current_name`.

## Apply

```bash
python priv/repo/chapter_name_correction_2026_27/fix_chapter_names.py --apply
```

Before applying updates, the script writes a backup JSON file under `backups/`.
It updates only the English chapter entry and preserves any other language
entries in the JSONB `chapter.name` array.

To choose the backup path explicitly:

```bash
python priv/repo/chapter_name_correction_2026_27/fix_chapter_names.py \
  --apply \
  --backup-file priv/repo/chapter_name_correction_2026_27/backups/chapter_name_backup_2026_27.json
```

## Rollback

Rollback restores the old `chapter.name` JSONB values from the backup file:

```bash
python priv/repo/chapter_name_correction_2026_27/fix_chapter_names.py \
  --rollback \
  --backup-file priv/repo/chapter_name_correction_2026_27/backups/chapter_name_backup_2026_27.json
```

Rollback is also dry-run by default. Add `--apply` to write:

```bash
python priv/repo/chapter_name_correction_2026_27/fix_chapter_names.py \
  --rollback \
  --apply \
  --backup-file priv/repo/chapter_name_correction_2026_27/backups/chapter_name_backup_2026_27.json
```

## Safety Notes

- The script updates only `chapter.name`; it does not touch LMS config tables.
- Updates are wrapped in one transaction.
- A local JSON backup is written before updates.
- The script refuses to run if current DB names do not match the correction
  file, unless `--no-current-name-check` is passed.
