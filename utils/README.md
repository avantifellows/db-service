# Database Utils

This folder contains utilities for managing database operations.

## Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your credentials:**
   Edit `.env` with your actual database credentials:
   - Production database credentials
   - Staging database credentials
   - Local database settings (usually don't need changes)

## Usage

### Fetch Data from Production/Staging

```bash
# From the project root
./utils/fetch-data.sh
```

This script will:
- ✅ Validate all required environment variables
- ⚠️  Ask for confirmation before proceeding
- 📥 Fetch data from the specified environment
- 📤 Replace the target schema and restore data in one transaction
- 🧹 Clean up temporary files

To sync production into staging:

```bash
FETCH_ENVIRONMENT=production
TARGET_ENVIRONMENT=staging
```

Staging sync skips data for `session`, `session_occurrence`, `group_session`,
and `user_session`. All Holistic table data is included for both staging and local
syncs. `public.oban_jobs` data is excluded for both targets so copied jobs cannot run.

The source is dumped before modifying the target. Schema reset and restore run in
one transaction with `ON_ERROR_STOP`: SQL failures return a nonzero exit code,
roll back the replacement, and retain the private dump for diagnosis. No staging
backup is created. Use PostgreSQL client tools compatible with the destination
(e.g. PostgreSQL 16 tools for a PostgreSQL 16 target).

`DB_FETCH_ENV_FILE=/path/to/config` can select a private configuration without
changing `utils/.env`. Dumps omit source ownership/ACLs and restore under the
target account; verify target service access after a refresh.

### Configuration

The script reads from `utils/.env` file. Key variables:

- `FETCH_ENVIRONMENT`: Source database, set to `production` or `staging`
- `TARGET_ENVIRONMENT`: Target database, set to `local` or `staging`
- `PROD_DB_*`: Production database credentials
- `STAGING_DB_*`: Staging database credentials
- `LOCAL_DB_*`: Local database settings

## Security

- ⚠️  **Never commit the `.env` file** - it contains sensitive credentials
- ✅ The `.env` file is automatically gitignored
- 🔒 Use strong passwords and secure access to production databases

## Features

- 🔍 **Validation**: Checks all required variables before running
- 🎨 **Colored output**: Easy to read status messages
- ⚠️  **Safety prompts**: Confirms before destructive operations
- 🛡️  **Error handling**: Exits cleanly on any errors
- 🧹 **Auto cleanup**: Removes temporary dump files

Replication publications and subscriptions are excluded from source dumps; they are environment-specific and can conflict with staging objects.
