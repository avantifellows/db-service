defmodule Dbservice.Repo.Migrations.ScholarshipCohortAcademics do
  use Ecto.Migration

  # The earlier cohorts' academic record (Program Team, 16 Nov 2026).
  #
  # The Earlier Cohorts import brings in what a scholar was PAID. The team also
  # holds how she DID — a row per term, a semester for engineering and a study
  # year for medical — and asked for a second tab to load it from a sheet of
  # the same shape.
  #
  # ## Why this is not `scholarship_scorecards`
  #
  # A scorecard is a document the SCHOLAR uploads and Alekhya verifies: it has
  # a status, an On Hold reason, a thread of messages, an attachment, and it
  # decides whether she is eligible for a top-up. None of that is true of a
  # 2021 result the team already holds on a spreadsheet. Importing these as
  # scorecards would put history into the queue of things somebody still has
  # to look at, and would let a sheet move a scholar's top-up eligibility —
  # against the team's own instruction that an academic upload "must not change
  # student status or portal access".
  #
  # So this table holds exactly what the sheet holds, and nothing reads it but
  # the screens that display her history.
  #
  # ## The key
  #
  # Scholar + financial year + stream + term, enforced here rather than trusted
  # to the importer: "re-uploading the same combination should update the
  # existing record" is an upsert, and an upsert needs the database to agree
  # with the application about what "the same" means. The scholar is the
  # application, which is what her Scholar ID resolves to.
  #
  # The stream is part of the key because it is what makes a term number
  # readable — semester 5 and year 5 are not the same thing — and the import
  # refuses a row whose stream disagrees with the scholar's own.
  def change do
    create table(:scholarship_cohort_academics) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      # "2025-2026", both years in full: the financial year, as the team's
      # sheet writes it and as the financial import already uses. NOT the
      # "2025-26" academic year a scorecard carries — the two are different
      # years that only sometimes coincide.
      add :financial_year, :string, null: false
      add :stream, :string, null: false
      # 'semester' | 'year' — which one `term_number` counts, decided by the
      # stream and stored so a reader never has to re-derive it.
      add :term_type, :string, null: false
      add :term_number, :integer, null: false
      # 'CGPA' | 'CPI' | 'GPA' | 'Percentage' | 'Grade', and the value as
      # WRITTEN. A string rather than a decimal because "A+" is one of the
      # answers, and because a CGPA out of 10 and a percentage out of 100 are
      # only comparable once you know which this is.
      add :grade_type, :string
      add :grade_value, :string
      # 'pass' | 'fail' | 'dropped' | 'awaiting'. `dropped` is the one a
      # scorecard has no word for, and the team asked for it by name.
      add :result, :string, null: false

      add :imported_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :imported_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(
             :scholarship_cohort_academics,
             [:application_id, :financial_year, :stream, :term_number],
             name: :scholarship_cohort_academics_term
           )

    # Her whole record, which is how both screens that show it read.
    create index(:scholarship_cohort_academics, [:application_id])

    # --- Which sheet an upload was -------------------------------------------
    #
    # The upload history is one table and now serves two tabs. Defaulted to
    # 'financial' because every row in it today is one.
    alter table(:scholarship_cohort_imports) do
      add :kind, :string, null: false, default: "financial"
    end

    create index(:scholarship_cohort_imports, [:kind, :inserted_at])
  end
end
