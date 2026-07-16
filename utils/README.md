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
- 🧹 Clear your target database
- 📥 Fetch data from the specified environment
- 📤 Restore data to your target database
- 🧹 Clean up temporary files

To sync production into staging:

```bash
FETCH_ENVIRONMENT=production
TARGET_ENVIRONMENT=staging
```

Staging sync skips data for `session`, `session_occurrence`, `group_session`, and `user_session`.

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
