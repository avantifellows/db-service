defmodule Dbservice.Repo.Migrations.CreateAlumniTable do
  use Ecto.Migration

  def change do
    create table(:alumni) do
      add :student_id, references(:student, on_delete: :nothing), null: false

      add :phone_number, :bigint
      add :email, :string

      add :which_competitive_exam_did_you_appear_for, :string
      add :did_you_take_a_gap_year, :string
      add :why_did_you_take_a_gap_year, :string

      add :if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for,
          :string

      # UG fields
      add :start_year_ug, :integer
      add :college_id_ug, references(:college, on_delete: :nothing)
      add :degree_ug, :string
      add :branch_ug, :string
      add :year_of_graduation_ug, :integer

      # PG fields
      add :start_year_pg, :integer
      add :college_id_pg, references(:college, on_delete: :nothing)
      add :degree_pg, :string
      add :branch_pg, :string
      add :year_of_graduation_pg, :integer

      add :past_internship_orgs, :string
      add :which_year_did_you_start_working, :integer
      add :starting_ctc_ug_range, :string
      add :current_ctc, :integer
      add :current_ctc_range, :string
      add :current_job_city, :string
      add :current_job_role, :string
      add :current_job_sector, :string
      add :current_org_name, :string
      add :years_of_experience, :integer
      add :linkedin_profile_link, :string

      add :what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job,
          :string

      add :ug_status, :string
      add :pg_status, :string
      add :employment_status, :string
      add :seeking_employment, :string
      add :contact_status, :string

      timestamps()
    end

    create unique_index(:alumni, [:student_id])
  end
end
