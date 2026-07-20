defmodule Dbservice.Repo.Migrations.CreateScholarshipTables do
  use Ecto.Migration

  # Phase-1 schema for the standalone scholarship service. These tables are
  # OWNED by the scholarship app (it reads/writes them at runtime via `pg`), but
  # per team convention all migrations on the shared Postgres are authored here
  # in db-service. Cross-domain references to core entities (colleges) are stored
  # as the stable string business key `college_id` — NOT a FK — so the
  # scholarship domain stays decoupled from the core `college` table and resolves
  # details through the db-service REST API.

  def change do
    # ── Cycles ────────────────────────────────────────────────────────────────
    create table(:scholarship_cycles) do
      add :name, :string, null: false
      add :opens_at, :utc_datetime
      add :closes_at, :utc_datetime
      add :is_active, :boolean, null: false, default: false

      timestamps()
    end

    # ── Applicants (one per verified phone; the dedup key) ────────────────────
    create table(:scholarship_applicants) do
      add :phone, :string, null: false
      add :name, :string
      # Optional link to an existing Avanti student, set only after a verified
      # match (entered ID's registered phone == this applicant's OTP phone).
      add :af_student_id, :string
      add :af_apaar_id, :string
      add :af_user_id, :integer

      timestamps()
    end

    create unique_index(:scholarship_applicants, [:phone])

    # ── OTPs (login + rate limiting) ──────────────────────────────────────────
    create table(:scholarship_otps) do
      add :phone, :string, null: false
      add :otp_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, null: false, default: 0
      add :consumed_at, :utc_datetime

      timestamps()
    end

    create index(:scholarship_otps, [:phone])
    create index(:scholarship_otps, [:expires_at])

    # ── Eligibility rules (one row per cycle) ─────────────────────────────────
    create table(:scholarship_eligibility_rules) do
      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      add :eligible_categories, {:array, :string}, null: false, default: []
      add :target_states, {:array, :string}, null: false, default: []
      # Escape hatch for cycle-specific rule params that don't fit the columns.
      add :extra_rules, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:scholarship_eligibility_rules, [:cycle_id])

    # ── Approved colleges (cycle-scoped; college_id is the string business key) ─
    create table(:scholarship_approved_colleges) do
      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      add :college_id, :string, null: false

      timestamps()
    end

    create unique_index(:scholarship_approved_colleges, [:cycle_id, :college_id])

    # ── Gate attempts (EVERY attempt persisted, incl. rejections — ADR 0001) ──
    create table(:scholarship_gate_attempts) do
      add :applicant_id, references(:scholarship_applicants, on_delete: :nilify_all)
      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      add :stream, :string
      add :college_id, :string
      add :category, :string
      add :home_state, :string
      add :result, :string, null: false
      add :rejection_reason, :string

      timestamps()
    end

    create index(:scholarship_gate_attempts, [:cycle_id])
    create index(:scholarship_gate_attempts, [:applicant_id])
    create index(:scholarship_gate_attempts, [:result])

    # ── Applications (one per applicant per cycle) ────────────────────────────
    create table(:scholarship_applications) do
      add :applicant_id, references(:scholarship_applicants, on_delete: :delete_all), null: false

      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      # Locked gate fields (typed).
      add :stream, :string
      add :college_id, :string
      add :category, :string
      add :home_state, :string

      add :is_af_student, :boolean, null: false, default: false

      # Stage form data as JSONB per section — schema evolves cycle-to-cycle
      # without migrations; Zod validates shape server-side before writes.
      add :stage1_data, :map, null: false, default: %{}
      add :stage2_data, :map, null: false, default: %{}
      add :stage3_data, :map, null: false, default: %{}

      # Fields promoted to typed columns for reviewer filtering / sorting.
      add :class12_percentage, :decimal
      add :exam_rank, :integer
      add :annual_income, :integer
      add :admission_status, :string

      add :status, :string, null: false, default: "in_progress"
      add :submitted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:scholarship_applications, [:applicant_id, :cycle_id])
    create index(:scholarship_applications, [:cycle_id, :status])
    create index(:scholarship_applications, [:home_state])
    create index(:scholarship_applications, [:category])

    # ── Documents ─────────────────────────────────────────────────────────────
    create table(:scholarship_documents) do
      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      add :doc_type, :string, null: false
      add :document_uuid, :string, null: false
      add :s3_key, :string, null: false
      add :mime_type, :string, null: false
      add :byte_size, :integer, null: false
      add :page_number, :integer, null: false, default: 1
      # Verification workflow lands in a later phase; column exists now so uploads
      # are captured with a sane default.
      add :verification_status, :string, null: false, default: "pending"
      add :notes, :string

      timestamps()
    end

    create index(:scholarship_documents, [:application_id])
    create index(:scholarship_documents, [:application_id, :doc_type])

    # ── Admin-editable option sets (stable codes + labels; af_lms ADR 0004) ────
    create table(:scholarship_option_sets) do
      add :code, :string, null: false
      add :label, :string, null: false
      add :allow_multi, :boolean, null: false, default: false
      add :sort_order, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:scholarship_option_sets, [:code])

    create table(:scholarship_options) do
      add :option_set_id,
          references(:scholarship_option_sets, on_delete: :delete_all),
          null: false

      add :code, :string, null: false
      add :label, :string, null: false
      add :sort_order, :integer, null: false, default: 0
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:scholarship_options, [:option_set_id, :code])

    # ── Status events (append-only audit trail) ───────────────────────────────
    create table(:scholarship_status_events) do
      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      add :from_status, :string
      add :to_status, :string, null: false
      add :action, :string, null: false
      # Who acted: "applicant" | "reviewer" | "system", + the actor's id/email.
      add :actor_type, :string, null: false
      add :actor_id, :string
      add :notes, :string

      timestamps()
    end

    create index(:scholarship_status_events, [:application_id])

    # ── Reviewers (staff; authorized via Google OAuth on @avantifellows.org) ──
    create table(:scholarship_reviewers) do
      add :email, :string, null: false
      add :name, :string
      add :role, :string, null: false, default: "reviewer"
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:scholarship_reviewers, [:email])
  end
end
