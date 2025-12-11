defmodule Dbservice.Repo.Migrations.CreateLmsPmSchoolVisitsTable do
  use Ecto.Migration

  def change do
    create table(:lms_pm_school_visits) do
      add :school_code, :string, size: 20, null: false
      add :pm_email, :string, size: 255, null: false
      add :visit_date, :date, null: false
      add :status, :string, size: 20, default: "in_progress", null: false
      add :data, :map, default: %{}, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    # Add status constraint
    create constraint(:lms_pm_school_visits, :status_constraint,
             check: "status IN ('in_progress', 'completed')"
           )

    # Add indexes for common queries
    create index(:lms_pm_school_visits, [:school_code])
    create index(:lms_pm_school_visits, [:pm_email])
    create index(:lms_pm_school_visits, [:visit_date])
    create index(:lms_pm_school_visits, [:status])

    # Composite index for common query patterns
    create index(:lms_pm_school_visits, [:school_code, :visit_date])
    create index(:lms_pm_school_visits, [:pm_email, :visit_date])
  end
end
