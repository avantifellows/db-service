# DB Service - Project Context

> **Last Updated:** December 2025
> **Purpose:** Comprehensive reference for AI coding agents and human engineers working on this project.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [User Flow & Purpose](#user-flow--purpose)
3. [Technical Stack](#technical-stack)
4. [Project Structure](#project-structure)
5. [Core Domain Modules](#core-domain-modules)
6. [Web Layer Architecture](#web-layer-architecture)
7. [API Endpoints Reference](#api-endpoints-reference)
8. [Database Schema](#database-schema)
9. [Data Import System](#data-import-system)
10. [Running Locally](#running-locally)
11. [Testing](#testing)
12. [Deployment](#deployment)
13. [Key Code Patterns](#key-code-patterns)

---

## Project Overview

**DB Service** is a Phoenix-based educational data management platform developed by **Avanti Fellows**. It serves as the central backend service for managing:

- Students, teachers, and user profiles
- Schools, batches, and academic programs
- Sessions and attendance tracking
- Educational content (curriculum, chapters, topics, resources)
- Enrollment records and academic year tracking
- Alumni career outcomes
- College predictor data (exams, cutoffs, branches)

The application exposes a comprehensive REST API with Swagger documentation and includes a LiveView-based admin UI for bulk data imports.

### Key Characteristics
- **Language:** Elixir 1.18.4 with Erlang/OTP 27
- **Framework:** Phoenix 1.7.21
- **Database:** PostgreSQL with Ecto ORM
- **Background Jobs:** Oban for async processing
- **API Docs:** Phoenix Swagger at `/docs/swagger`

---

## User Flow & Purpose

### Primary Users

1. **External Systems (API Consumers)**
   - Other Avanti Fellows applications call DB Service APIs
   - Operations: CRUD for students, teachers, schools, sessions, resources
   - Authentication: Bearer token in Authorization header

2. **Admin Users (Web UI)**
   - Access LiveView imports at `/imports`
   - Upload CSV/Google Sheets for bulk data operations
   - Monitor import progress in real-time
   - Protected by basic HTTP authentication

### Core Use Cases

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DB SERVICE FLOWS                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    REST API    ┌─────────────────────────────┐   │
│  │ External     │ ─────────────> │ Student/Teacher/School      │   │
│  │ Applications │ <───────────── │ Management                  │   │
│  └──────────────┘                └─────────────────────────────┘   │
│                                                                      │
│  ┌──────────────┐    LiveView    ┌─────────────────────────────┐   │
│  │ Admin Users  │ ─────────────> │ Bulk CSV Imports            │   │
│  │              │ <───────────── │ (Real-time progress)        │   │
│  └──────────────┘                └─────────────────────────────┘   │
│                                                                      │
│  ┌──────────────┐   Background   ┌─────────────────────────────┐   │
│  │ Google       │ ─────────────> │ Oban Job Processing         │   │
│  │ Sheets       │                │ (Import Workers)            │   │
│  └──────────────┘                └─────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Enrollment Lifecycle

```
Student Created → Enrolled in Batch → Active Status
                                         ↓
                              ┌──────────┴──────────┐
                              ↓                     ↓
                         Dropout              Batch Movement
                              ↓                     ↓
                        Re-Enrollment        New Batch Assigned
```

---

## Technical Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Language | Elixir | 1.18.4 |
| Runtime | Erlang/OTP | 27 |
| Web Framework | Phoenix | 1.7.21 |
| Real-time UI | Phoenix LiveView | 1.0.10 |
| ORM | Ecto | 3.12.1 |
| Database | PostgreSQL | 13+ |
| Job Queue | Oban | 2.19.4 |
| API Docs | Phoenix Swagger | 0.8.3 |
| CSS | Tailwind CSS | 4.0 |
| JS Bundler | esbuild | 0.9 |
| HTTP Client | HTTPoison | 2.2.3 |
| Google APIs | google_api_sheets | 0.35.0 |
| Auth | Goth (Google OAuth) | 1.4.5 |

### Dev Tools
- **Credo** - Code linting
- **Dialyxir** - Static type analysis
- **ex_check** - Unified code quality checks
- **Faker** - Test data generation

---

## Project Structure

```
db-service/
├── lib/
│   ├── dbservice/                    # Core business logic (113 modules)
│   │   ├── application.ex            # OTP application supervisor
│   │   ├── repo.ex                   # Ecto repository
│   │   ├── users.ex                  # User context (946 lines)
│   │   ├── students.ex, teachers.ex  # User type contexts
│   │   ├── schools.ex                # School management
│   │   ├── batches.ex                # Batch/cohort management
│   │   ├── groups.ex                 # Hierarchical grouping
│   │   ├── sessions.ex               # Session management
│   │   ├── resources.ex              # Learning resources (570 lines)
│   │   ├── enrollment_records.ex     # Enrollment tracking
│   │   ├── data_import.ex            # Import system (546 lines)
│   │   ├── constants/
│   │   │   └── mappings.ex           # CSV field mappings (725 lines)
│   │   ├── services/                 # Complex business operations
│   │   │   ├── enrollment_service.ex
│   │   │   ├── batch_enrollment_service.ex
│   │   │   ├── dropout_service.ex
│   │   │   ├── re_enrollment_service.ex
│   │   │   ├── student_update_service.ex
│   │   │   └── group_update_service.ex
│   │   └── utils/
│   │       └── util.ex               # Common utilities
│   │
│   └── dbservice_web/                # Web layer
│       ├── router.ex                 # Route definitions
│       ├── endpoint.ex               # HTTP endpoint config
│       ├── controllers/              # 54 REST controllers
│       ├── json/                     # 49 JSON serializers
│       ├── swagger_schemas/          # 30+ API schemas
│       ├── live/import_live/         # LiveView for imports
│       ├── components/               # UI components
│       └── plugs/                    # Custom middleware
│
├── config/
│   ├── config.exs                    # Base configuration
│   ├── dev.exs                       # Development config
│   ├── test.exs                      # Test config
│   ├── prod.exs                      # Production config
│   └── runtime.exs                   # Runtime configuration
│
├── priv/
│   ├── repo/
│   │   ├── migrations/               # 170 database migrations
│   │   ├── seeds.exs                 # Main seed runner
│   │   └── seeds/                    # 41 seed data files
│   └── static/                       # Static assets, swagger.json
│
├── test/
│   ├── dbservice/                    # Context tests
│   ├── dbservice_web/controllers/    # Controller tests
│   └── support/fixtures/             # 18 fixture modules
│
├── docs/
│   ├── INSTALLATION.md               # Setup guide
│   ├── DEPLOYMENT.md                 # Deployment guide
│   └── SWAGGER.md                    # API docs guide
│
├── utils/
│   ├── fetch-data.sh                 # DB sync script
│   └── README.md                     # Utils documentation
│
├── terraform/                        # AWS infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   ├── production.tfvars
│   └── staging.tfvars
│
├── .github/workflows/
│   ├── ci.yml                        # CI pipeline
│   ├── production_deploy.yml         # Production deployment
│   └── staging_deploy.yml            # Staging deployment
│
├── mix.exs                           # Project manifest
├── start_server_macos.sh             # macOS dev startup
└── CLAUDE.md                         # AI assistant guide
```

---

## Core Domain Modules

### User Management (`lib/dbservice/users.ex`)

Central module for all user types with 946 lines of business logic.

**Key Entities:**
- `User` - Base user with name, email, phone, address
- `Student` - Extends user with student_id, apaar_id, academic details
- `Teacher` - Extends user with teacher_id, designation
- `Candidate` - For exam/recruitment

**Important Functions:**
```elixir
# Create student with associated user (transactional)
Users.create_student_with_user(user_params, student_params)

# Upsert with duplicate validation on student_id and apaar_id
Users.create_or_update_student(student_params)

# Flexible lookup by either identifier
Users.get_student_by_id_or_apaar_id(identifier)

# Associate user with groups
Users.update_group(user_id, group_ids)
```

### Group System (`lib/dbservice/groups.ex`)

Hierarchical grouping for access control. Groups are auto-created when creating schools, batches, grades, products.

**Group Types:**
- `school` - School-level grouping
- `batch` - Batch/cohort grouping
- `grade` - Grade-level grouping
- `product` - Product-level grouping
- `program` - Program grouping
- `auth_group` - Authorization grouping

**Key Pattern:** Every organizational entity creates an associated Group for unified access control.

### Enrollment Records (`lib/dbservice/enrollment_records.ex`)

Tracks user enrollment in groups across academic years.

**Fields:**
- `user_id`, `group_id`, `group_type`
- `academic_year` - e.g., "2024-25"
- `is_current` - Active enrollment flag

**Key Functions:**
```elixir
# Get current grade for user
EnrollmentRecords.get_current_grade_id(user_id)

# Get all enrollments for academic year
EnrollmentRecords.get_enrollment_records_by_user_and_academic_year(user_id, year)
```

### Resources (`lib/dbservice/resources.ex`)

Educational content management with 570 lines.

**Resource Types:**
- `test` - Assessments with nested problem structure
- `problem` - Individual questions
- `video` - Learning videos
- `chapter`, `topic` - Content hierarchy

**Key Functions:**
```elixir
# Complex query for test problems in specific language
Resources.get_problems_by_test_and_language(test_id, language_code, curriculum_id)

# Generate resource codes like "P0000024"
Resources.generate_next_resource_code(type)
```

### Services Layer (`lib/dbservice/services/`)

Complex operations spanning multiple domains:

| Service | Purpose |
|---------|---------|
| `EnrollmentService` | Core enrollment with group validation |
| `BatchEnrollmentService` | Batch-specific enrollments |
| `DropoutService` | Student dropout handling |
| `ReEnrollmentService` | Re-enrollment after dropout |
| `StudentUpdateService` | Profile updates |
| `GroupUpdateService` | Group synchronization |

---

## Web Layer Architecture

### Router (`lib/dbservice_web/router.ex`)

**Pipelines:**
- `:api` - JSON API requests
- `:browser` - HTML with sessions, CSRF
- `:dashboard_auth` - Basic HTTP auth for admin routes

**Route Groups:**

```elixir
# Browser routes (LiveView)
scope "/" do
  live "/imports", ImportLive.Index
  live "/imports/new", ImportLive.New
  live "/imports/:id", ImportLive.Show
  get "/templates/:type/download", TemplateController, :download_csv_template
end

# Protected admin routes
scope "/" do
  pipe_through [:browser, :dashboard_auth]
  post "/imports/dropout", ImportController, :create_dropout_import
  post "/imports/re_enrollment", ImportController, :create_re_enrollment_import
end

# API routes
scope "/api" do
  resources "/user", UserController
  resources "/student", StudentController
  resources "/teacher", TeacherController
  # ... 80+ endpoints
end

# Swagger documentation
scope "/docs/swagger" do
  forward "/", PhoenixSwagger.Plug.SwaggerUI
end
```

### Controllers (`lib/dbservice_web/controllers/`)

54 controllers following Phoenix conventions:

**Pattern:**
```elixir
defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller
  use PhoenixSwagger

  action_fallback DbserviceWeb.FallbackController

  def index(conn, params) do
    students = Students.list_student(params)
    render(conn, :index, students: students)
  end

  def create(conn, %{"student" => params}) do
    with {:ok, %Student{} = student} <- Students.create_student(params) do
      conn
      |> put_status(:created)
      |> render(:show, student: student)
    end
  end
end
```

### JSON Serializers (`lib/dbservice_web/json/`)

49 modules for consistent JSON responses:

```elixir
defmodule DbserviceWeb.StudentJSON do
  def index(%{students: students}) do
    Enum.map(students, &render/1)
  end

  def show(%{student: student}) do
    render(student)
  end

  def render(student) do
    %{
      id: student.id,
      student_id: student.student_id,
      stream: student.stream,
      # ... all fields
    }
  end
end
```

### LiveView Import UI (`lib/dbservice_web/live/import_live/`)

Real-time data import interface:

- **Index** - List imports with status, progress bars, pagination
- **New** - Form to initiate imports from Google Sheets
- **Show** - Detailed import view with error logs

**Features:**
- PubSub for real-time status updates
- Stop import with confirmation modal
- Progress visualization
- Error details per row

---

## API Endpoints Reference

### User Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/user` | List users (filterable) |
| POST | `/api/user` | Create/upsert user |
| GET | `/api/user/:id` | Get user details |
| PATCH | `/api/user/:id` | Update user |
| DELETE | `/api/user/:id` | Delete user |
| POST | `/api/user/:id/update-groups` | Update user's groups |
| GET | `/api/user/:id/sessions` | Get user's sessions |

### Student Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/student` | List students |
| POST | `/api/student` | Create student |
| GET | `/api/student/get-schema` | Get schema fields |
| POST | `/api/student/generate-id` | Generate unique ID |
| POST | `/api/student/verify-student` | Verify student data |
| PATCH | `/api/dropout` | Mark as dropout |
| PATCH | `/api/re-enroll` | Re-enroll student |
| PATCH | `/api/enrolled` | Enroll in batch |
| POST | `/api/student/batch-process` | Bulk operations |
| POST | `/api/student/create-with-enrollments` | Full enrollment setup |

### Group Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/group` | List groups (type, child_id filterable) |
| POST | `/api/group/:id/update-users` | Assign users to group |
| POST | `/api/group/:id/update-sessions` | Assign sessions |

### Session Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/session` | List sessions |
| POST | `/api/session/search` | Bulk search by platform_ids |
| POST | `/api/session/:id/update-groups` | Assign groups |
| POST | `/api/session-occurrence/search` | Search occurrences |

### Resource Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/resource` | List resources |
| GET | `/api/resource/test/:id/problems` | Get test problems |
| GET | `/api/problems` | Fetch all problems |
| GET | `/api/resources/curriculum` | Curriculum resources |

### Full CRUD Available For
`school`, `batch`, `program`, `curriculum`, `chapter`, `topic`, `concept`, `subject`, `grade`, `teacher`, `candidate`, `alumni`, `college`, `exam`, `branch`, `cutoffs`, `enrollment-record`, `auth-group`, `tag`, `language`, `skill`, `status`

---

## Database Schema

### Core Entity Relationships

```
User (base)
├── Student (student_id, apaar_id, academic details)
├── Teacher (teacher_id, subject, designation)
└── Candidate (candidate_id)

School ──┬── Group (type="school")
         └── Students/Teachers (via enrollments)

Batch ───┬── Group (type="batch")
         ├── Students (via enrollments)
         └── Teachers (via assignments)

Grade ───┬── Group (type="grade")
         └── Students (via enrollments)

Session ─┬── SessionOccurrence
         ├── GroupSession (many-to-many with groups)
         └── UserSession (attendance tracking)

Curriculum
├── Chapter ──── ChapterCurriculum
│   └── Topic ── TopicCurriculum
│       └── Concept
└── Resources (via ResourceCurriculum)

Resource
├── ResourceCurriculum
├── ResourceChapter
├── ResourceTopic
├── ResourceConcept
├── ProblemLanguage (multilingual problems)
└── Tags

EnrollmentRecord (user_id, group_id, group_type, academic_year, is_current)
```

### Key Tables (170 migrations)

**User Domain:** `user`, `student`, `teacher`, `candidate`, `user_profile`, `student_profile`, `teacher_profile`

**Organization:** `school`, `batch`, `program`, `product`, `school_batch`

**Grouping:** `group`, `group_user`, `group_session`, `auth_group`

**Academic:** `grade`, `curriculum`, `subject`, `chapter`, `topic`, `concept`, `learning_objective`

**Resources:** `resource`, `tag`, `language`, `resource_curriculum`, `resource_chapter`, `resource_topic`, `resource_concept`, `problem_languages`

**Sessions:** `session`, `session_occurrence`, `user_session`

**Enrollment:** `enrollment_record`, `status`

**Exams/College:** `exam`, `exam_occurrence`, `college`, `branch`, `cutoffs`, `student_exam_record`, `demographic_profile`

**Alumni:** `alumni` (education, employment, CTC, competitive exams)

**System:** `oban_jobs`, `import_table`, `form_schema`

---

## Data Import System

### Supported Import Types (12)

| Type | Description |
|------|-------------|
| `student` | Create new students with users |
| `student_update` | Update existing student fields |
| `teacher_addition` | Add new teachers |
| `teacher_batch_assignment` | Assign teachers to batches |
| `alumni_addition` | Add alumni records |
| `batch_movement` | Move students between batches |
| `dropout` | Mark students as dropout |
| `re_enrollment` | Re-enroll dropped students |
| `update_incorrect_batch_id_to_correct_batch_id` | Batch correction |
| `update_incorrect_school_to_correct_school` | School correction |
| `update_incorrect_grade_to_correct_grade` | Grade correction |
| `update_incorrect_auth_group_to_correct_auth_group` | Auth group correction |

### Import Workflow

```
1. User navigates to /imports/new
2. Selects import type, provides Google Sheet URL
3. System validates URL and downloads sheet
4. CSV headers validated against schema (lib/dbservice/constants/mappings.ex)
5. Import queued via Oban (lib/dbservice/data_import/import_worker.ex)
6. Rows processed incrementally
7. Real-time progress updates via PubSub
8. User can stop import at any time
9. Results available with per-row errors
```

### Key Files
- `lib/dbservice/data_import.ex` - Import lifecycle management (546 lines)
- `lib/dbservice/constants/mappings.ex` - CSV field mappings (725 lines)
- `lib/dbservice/data_import/import_worker.ex` - Oban worker
- `lib/dbservice_web/live/import_live/` - LiveView UI

---

## Running Locally

### Prerequisites
- Elixir 1.18.4
- Erlang/OTP 27
- PostgreSQL 13+
- Node.js 18+ (for assets)

### Setup Steps

```bash
# 1. Clone repository
git clone https://github.com/avantifellows/db-service.git
cd db-service

# 2. Install dependencies
mix deps.get
cd assets && yarn && cd ..

# 3. Configure environment
cp config/.env.example config/.env
# Edit config/.env with:
#   BEARER_TOKEN="your_api_token"
#   PATH_TO_CREDENTIALS="/path/to/google-service-account.json"

# 4. Setup database
# Ensure PostgreSQL is running
createdb dbservice_dev
psql -d dbservice_dev -c 'CREATE EXTENSION "uuid-ossp";'

# 5. Run migrations and seed
mix ecto.setup

# 6. Generate Swagger docs
mix phx.swagger.generate

# 7. Start server
mix phx.server
# OR for macOS:
./start_server_macos.sh
```

### Access Points
- **Application:** http://localhost:4000
- **API Documentation:** http://localhost:4000/docs/swagger/index.html
- **LiveDashboard:** http://localhost:4000/dashboard
- **Imports UI:** http://localhost:4000/imports

### Common Commands

```bash
# Development
mix phx.server              # Start server
iex -S mix phx.server       # Start with IEx shell

# Database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Drop + recreate + seed
mix ecto.gen.migration NAME # Generate migration

# Code Quality
mix format                  # Format code
mix check                   # Run all checks (credo, dialyzer)
mix credo                   # Lint only
mix dialyzer                # Type analysis

# Testing
mix test                    # Run all tests
mix test test/path_test.exs # Run specific test
mix test --trace            # Verbose output

# API Docs
mix phx.swagger.generate    # Regenerate swagger.json

# Assets
mix assets.deploy           # Build for production
```

---

## Testing

### Test Structure

```
test/
├── dbservice/                        # Domain/context tests
│   ├── users_test.exs
│   ├── groups_test.exs
│   ├── schools_test.exs
│   ├── sessions_test.exs
│   ├── services/                     # Service tests
│   │   ├── batch_enrollment_service_test.exs
│   │   ├── enrollment_service_test.exs
│   │   └── student_update_service_test.exs
│   └── utils/                        # Utility tests
│       ├── batch_movement_test.exs
│       ├── import_worker_test.exs
│       └── student_enrollment_test.exs
├── dbservice_web/controllers/        # Controller tests
│   ├── user_controller_test.exs
│   ├── student_controller_test.exs
│   └── ...
└── support/
    ├── fixtures/                     # 18 fixture modules
    ├── conn_case.ex                  # HTTP test setup
    └── data_case.ex                  # Database test setup
```

### Fixture Pattern

```elixir
# test/support/fixtures/users_fixtures.ex
defmodule Dbservice.UsersFixtures do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user#{System.unique_integer()}@example.com",
        full_name: Faker.Person.name(),
        phone: Faker.Phone.EnUs.phone()
      })
      |> Dbservice.Users.create_user()
    user
  end

  def student_fixture(attrs \\ %{}) do
    user = user_fixture()
    {:ok, student} =
      attrs
      |> Enum.into(%{user_id: user.id, student_id: "STU#{System.unique_integer()}"})
      |> Dbservice.Students.create_student()
    student
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific file
mix test test/dbservice/users_test.exs

# Run specific test by line number
mix test test/dbservice/users_test.exs:42

# Run with coverage
mix test --cover

# Run in watch mode (requires mix_test_watch)
mix test.watch
```

---

## Deployment

### CI/CD Pipeline

**CI (`.github/workflows/ci.yml`):**
- Triggers on PR and push to main
- PostgreSQL 13 service container
- Steps: format check, dialyzer PLT cache, `mix check`
- Tests currently disabled in CI

**Credo Requirements (enforced by CI):**
- Max function nesting depth: 2 (extract helpers to reduce nesting)
- Avoid `length/1` for empty checks (use `list != []` or `list == []` instead)
- Follow standard Elixir formatting (`mix format`)

**Staging Deploy (`.github/workflows/staging_deploy.yml`):**
- Manual trigger via `workflow_dispatch` (Actions → Run workflow → Select branch)
- SSH to EC2, pulls selected branch, runs migrations
- Supports deploying feature branches for testing

**Production Deploy (`.github/workflows/production_deploy.yml`):**
- Triggers on push to `release` branch
- SSH to EC2, updates env vars, pulls code
- Runs: deps.get, deps.compile, ecto.migrate, phx.swagger.generate, assets.deploy
- Starts detached Elixir process

### Test Environment

Tests can run without Google Cloud credentials. The application detects `environment: :test` config and skips Goth initialization if credentials are missing. This allows running tests locally without a Google service account.

```elixir
# config/test.exs
config :dbservice, environment: :test
```

### Environment Variables (Production)

```bash
DATABASE_URL="postgres://user:pass@host/dbname"
SECRET_KEY_BASE="64-char-secret"
PHX_HOST="api.avantifellows.org"
PORT="4000"
POOL_SIZE="10"
BEARER_TOKEN="api-auth-token"
PATH_TO_CREDENTIALS="/path/to/google-creds.json"
WHITELISTED_DOMAINS="domain1.com,domain2.com"
DASHBOARD_USER="admin"
DASHBOARD_PASS="password"
```

### Infrastructure (Terraform)

AWS infrastructure managed via Terraform in `/terraform`:

- **EC2:** Auto-scaling group (t3.small/medium)
- **RDS:** PostgreSQL (t3.micro/small)
- **ALB:** Application Load Balancer with health checks
- **Cloudflare:** DNS management

**Environments:**
- Production: `api.avantifellows.org` (release branch)
- Staging: `staging-dbservice-test.avantifellows.org` (main branch)

---

## Key Code Patterns

### 1. Context Pattern (Phoenix Convention)

Each domain has a context module with all operations:

```elixir
# lib/dbservice/users.ex
defmodule Dbservice.Users do
  alias Dbservice.Repo
  alias Dbservice.Users.{User, Student}

  def list_users(params \\ %{}) do
    User
    |> apply_filters(params)
    |> Repo.all()
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

### 2. Transactional Operations

Multi-entity operations wrapped in transactions:

```elixir
def create_student_with_user(user_params, student_params) do
  Repo.transaction(fn ->
    with {:ok, user} <- create_user(user_params),
         {:ok, student} <- create_student(Map.put(student_params, :user_id, user.id)) do
      {user, student}
    else
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end)
end
```

### 3. Dynamic Query Building

```elixir
def apply_filters(query, params) do
  Enum.reduce(params, query, fn
    {"student_id", value}, q -> where(q, [s], s.student_id == ^value)
    {"stream", value}, q -> where(q, [s], s.stream == ^value)
    {"name", value}, q -> where(q, [s], ilike(s.name, ^"%#{value}%"))
    _, q -> q
  end)
end
```

### 4. Controller with Fallback

```elixir
defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller
  action_fallback DbserviceWeb.FallbackController

  def show(conn, %{"id" => id}) do
    case Students.get_student(id) do
      nil -> {:error, :not_found}
      student -> render(conn, :show, student: student)
    end
  end
end

defmodule DbserviceWeb.FallbackController do
  use DbserviceWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(DbserviceWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(DbserviceWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
```

### 5. Oban Background Jobs

```elixir
# lib/dbservice/data_import/import_worker.ex
defmodule Dbservice.DataImport.ImportWorker do
  use Oban.Worker, queue: :imports

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"import_id" => import_id}}) do
    import = DataImport.get_import!(import_id)
    # Process rows...
    :ok
  end
end

# Enqueue job
%{import_id: import.id}
|> ImportWorker.new()
|> Oban.insert()
```

### 6. LiveView Real-time Updates

```elixir
# Subscribe to updates
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Dbservice.PubSub, "imports")
  end
  {:ok, assign(socket, imports: list_imports())}
end

# Handle broadcasts
def handle_info({:import_updated, import}, socket) do
  {:noreply, update(socket, :imports, &update_import(&1, import))}
end

# Broadcast from worker
Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import})
```

---

## Quick Reference

### File Locations for Common Tasks

| Task | Location |
|------|----------|
| Add new API endpoint | `lib/dbservice_web/router.ex`, create controller in `controllers/` |
| Add new domain entity | Create in `lib/dbservice/`, add migration, add controller/JSON |
| Add new import type | Update `lib/dbservice/constants/mappings.ex` |
| Modify enrollment logic | `lib/dbservice/services/enrollment_service.ex` |
| Add Swagger docs | Update controller with `swagger_path` + `lib/dbservice_web/swagger_schemas/` |
| Add background job | Create worker in `lib/dbservice/data_import/` using Oban.Worker |

### Environment Files

| File | Purpose |
|------|---------|
| `config/.env` | Local environment variables |
| `config/dev.exs` | Development settings |
| `config/prod.exs` | Production settings |
| `terraform/*.tfvars` | Infrastructure variables |

---

*This document should be updated when significant changes are made to the project architecture, dependencies, or workflows.*
