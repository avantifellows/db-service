# Migration: Add program_ids to user_permission

## Overview

Add `program_ids` column to `user_permission` table to support program-based access control.

## Schema Change

```sql
ALTER TABLE user_permission
ADD COLUMN program_ids INTEGER[] DEFAULT '{}';
```

## Column Details

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `program_ids` | `INTEGER[]` | `'{}'` | Array of program IDs the user can access |

## Program ID Reference

| Program | ID |
|---------|-----|
| JNV CoE | 1 |
| JNV Nodal | 2 |
| JNV NVS | 64 |

## Example Usage

```sql
-- NVS-only PM
UPDATE user_permission
SET program_ids = ARRAY[64]
WHERE email = 'nvs-pm@avantifellows.org';

-- CoE + Nodal access
UPDATE user_permission
SET program_ids = ARRAY[1, 2]
WHERE email = 'coe-teacher@avantifellows.org';

-- All programs
UPDATE user_permission
SET program_ids = ARRAY[1, 2, 64]
WHERE email = 'admin@avantifellows.org';
```

## Behavior

- Empty array `'{}'` = no program access
- Users must have explicit program assignment
- Access is intersection of user's `program_ids` and programs present at school (via students → batches)

## Rollback

```sql
ALTER TABLE user_permission
DROP COLUMN program_ids;
```
