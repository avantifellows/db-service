defmodule Dbservice.Repo.Migrations.ScholarshipPhase4RequiredForms do
  use Ecto.Migration

  # Phase 4 — the required forms become the programme team's own list
  # (Sanghamitra, 23 Oct 2026), rather than two names written into the app:
  #
  #   "Start with Consent and Undertaking, and allow Reviewers to add more.
  #    Students should download templates, upload signed copies, and track
  #    status (Pending / Submitted / Accepted / Re-upload needed). Reviewers
  #    should be able to review them."
  #
  # Three things follow, and this migration is all three.
  #
  # ## 1. The list is data
  #
  # A reviewer adds a form, so the list cannot live in code. Consent and
  # Undertaking are seeded HERE rather than in a seeder — seeders do not run on
  # deploy — and `is_active` retires one without deleting it, because a form
  # that scholars have already signed must keep its rows readable.
  #
  # ## 2. A form has a blank to download
  #
  # The template is a file belonging to the form, so it goes in the existing
  # `scholarship_attachments` with `owner_type = 'required_form'`. That column
  # is a string and not an enum precisely so a new owner costs no migration,
  # and a template then gets the same S3 handling, the same presigned reads and
  # the same "nothing is overwritten" behaviour as every other file here.
  #
  # ## 3. A signed form now has a verdict
  #
  # Until now a student upload was kept and never judged. A required form is
  # the exception the team has asked for: a reviewer accepts it or asks for it
  # again. The three states live on the upload row; the fourth — Pending —
  # is the ABSENCE of a row, because a form she has not sent has nothing to
  # hang a status on.
  def up do
    create table(:scholarship_required_forms) do
      add :name, :string, null: false
      # What it is for, in the words the scholar reads under its name.
      add :description, :text
      # Retires a form without deleting it: the signed copies stay readable.
      add :is_active, :boolean, null: false, default: true
      # The order the team wants them asked for, lowest first.
      add :display_order, :integer, null: false, default: 0
      add :created_by, references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:scholarship_required_forms, [:name])

    execute """
            INSERT INTO scholarship_required_forms
              (name, is_active, display_order, inserted_at, updated_at)
            VALUES
              ('Consent form', true, 1, NOW(), NOW()),
              ('Undertaking', true, 2, NOW(), NOW())
            """,
            "DELETE FROM scholarship_required_forms WHERE name IN ('Consent form', 'Undertaking')"

    alter table(:scholarship_student_uploads) do
      # Which form this signed copy answers. A real column rather than a key in
      # the details blob (ADR 0003 in the app): the reviewer's queue joins on
      # it, so it is queried, and the blob is for what is only displayed.
      add :required_form_id, references(:scholarship_required_forms, on_delete: :restrict)
      # 'submitted' | 'accepted' | 'reupload' — the three states a row can be
      # in. Pending is the absence of a row. Default 'submitted' because that
      # is what every upload is the moment it arrives, including the ones that
      # are not forms at all and are never reviewed.
      add :status, :string, null: false, default: "submitted"
      add :review_note, :text
      add :reviewed_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
    end

    create index(:scholarship_student_uploads, [:required_form_id])
    create index(:scholarship_student_uploads, [:status])

    # Any signed form already uploaded against the app's hardcoded list is
    # matched to the seeded row by the name it was filed under. There will
    # normally be none — this migration follows the one that created those
    # uploads by a day — but an environment that got the app in between must
    # not end up with forms pointing at nothing.
    execute """
            UPDATE scholarship_student_uploads u
               SET required_form_id = f.id
              FROM scholarship_required_forms f
             WHERE u.kind = 'form'
               AND u.required_form_id IS NULL
               AND LOWER(TRIM(u.title)) = LOWER(f.name)
            """,
            "UPDATE scholarship_student_uploads SET required_form_id = NULL WHERE kind = 'form'"
  end

  def down do
    drop index(:scholarship_student_uploads, [:status])
    drop index(:scholarship_student_uploads, [:required_form_id])

    alter table(:scholarship_student_uploads) do
      remove :reviewed_at
      remove :reviewed_by
      remove :review_note
      remove :status
      remove :required_form_id
    end

    # The templates belong to the forms being dropped.
    execute "DELETE FROM scholarship_attachments WHERE owner_type = 'required_form'"

    drop table(:scholarship_required_forms)
  end
end
