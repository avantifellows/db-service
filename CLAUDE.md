# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dbservice is a Phoenix 1.7 web application (Elixir 1.18.4, OTP 27) that serves as an educational data management platform. It provides REST APIs for managing students, teachers, schools, batches, sessions, and academic content, with a LiveView UI for data imports.

## Common Commands

```bash
# Setup and dependencies
mix setup                     # Install deps + create/migrate/seed database
mix deps.get                  # Get dependencies only

# Development
mix phx.server                # Start server on localhost:4000
./start_server_macos.sh       # macOS: auto-generates Swagger and starts server

# Database
mix ecto.migrate              # Run pending migrations
mix ecto.reset                # Drop + recreate + migrate + seed database
mix run priv/repo/seeds.exs   # Seed database with sample data

# Code quality
mix format                    # Format code
mix format --check-formatted  # Check formatting (CI)
mix check                     # Run all checks: format, credo, dialyzer
mix credo                     # Lint only
mix dialyzer                  # Type analysis only

# API documentation
mix phx.swagger.generate      # Generate swagger.json
# Access at: http://localhost:4000/docs/swagger/index.html

# Assets
mix assets.deploy             # Minify CSS/JS + digest for production
```

Note: `mix check` has tests disabled (configured in `.check.exs`). Run `mix test` separately if needed.

## Architecture

### Domain Structure (`lib/dbservice/`)

The codebase follows Phoenix/Ecto conventions with domain modules under `Dbservice.*`:

- **Core entities**: `Users`, `Students`, `Teachers`, `Schools`, `Batches`, `Groups`, `Sessions`
- **Academic content**: `Curriculums`, `Subjects`, `Chapters`, `Topics`, `Concepts`, `Resources`
- **College predictors**: `Colleges`, `Exams`, `Cutoffs`, `Branches`
- **Supporting**: `EnrollmentRecords`, `Tags`, `Profiles`, `Alumni`

Each domain module typically contains:
- Schema definition with Ecto changesets
- Context module with CRUD operations and business logic

### Service Layer (`lib/dbservice/services/`)

Complex operations that span multiple domains:
- `batch_enrollment_service` - Student batch enrollments
- `dropout_service` / `re_enrollment_service` - Status management
- `group_update_service` - Group synchronization
- `student_update_service` - Bulk student operations

### Web Layer (`lib/dbservice_web/`)

- **Controllers** (`/controllers`): 53 controllers handling REST API endpoints
- **JSON serializers** (`/json`): Response formatting
- **Swagger schemas** (`/swagger_schemas`): API documentation definitions
- **LiveView** (`/live/import_live`): Interactive CSV import UI
- **Router**: API routes under `/api`, LiveView under `/imports`, Swagger at `/docs/swagger`

### Background Jobs

Uses Oban for async processing, primarily for CSV imports. Workers are in `lib/dbservice/data_import/`.

### Authentication

- API: Bearer token authentication (configured via `BEARER_TOKEN` env var)
- Admin routes: Basic auth (dropout/re-enrollment imports, LiveDashboard in prod)
- Google Cloud: Service account auth via Goth for Sheets integration

## Key Files

- `lib/dbservice_web/router.ex` - All route definitions
- `lib/dbservice/application.ex` - OTP supervision tree
- `lib/dbservice/repo.ex` - Ecto repository config
- `config/config.exs` - Base configuration
- `config/dev.exs` / `config/prod.exs` - Environment overrides

## Database

PostgreSQL with Ecto. Requires `uuid-ossp` extension for UUID generation.

```bash
# Enable UUID extension (one-time setup)
psql -d dbservice_dev -c 'CREATE EXTENSION "uuid-ossp";'
```

Dev database: `dbservice_dev` (credentials default to postgres/postgres in `config/dev.exs`)

## Environment Variables

Required in `config/.env`:
```bash
BEARER_TOKEN="your_api_auth_token"
PATH_TO_CREDENTIALS="/path/to/google-service-account.json"
```

Optional:
```bash
DASHBOARD_USER="admin"      # For protected routes
DASHBOARD_PASS="password"
PHX_HOST="your-domain.com"  # Production host
```
