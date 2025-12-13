defmodule Dbservice.Alumnis.Alumni do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "alumni" do
    field :which_competitive_exam_did_you_appear_for, :string
    field :did_you_take_a_gap_year, :string
    field :why_did_you_take_a_gap_year, :string

    field :if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for,
          :string

    # UG fields
    field :start_year_ug, :integer
    field :degree_ug, :string
    field :year_of_graduation_ug, :integer

    # PG fields
    field :start_year_pg, :integer
    field :degree_pg, :string
    field :year_of_graduation_pg, :integer

    field :past_internship_orgs, :string
    field :which_year_did_you_start_working, :integer
    field :starting_ctc_ug_range, :string
    field :current_ctc, :integer
    field :current_ctc_range, :string
    field :current_job_city, :string
    field :current_job_role, :string
    field :current_job_sector, :string
    field :current_org_name, :string
    field :years_of_experience, :integer
    field :linkedin_profile_link, :string

    field :what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job,
          :string

    field :ug_status, :string
    field :pg_status, :string
    field :employment_status, :string
    field :seeking_employment, :string
    field :contact_status, :string
    field :current_status, :string
    field :scholarship_availed, :string
    field :skilling_programs, :string

    belongs_to :student, Dbservice.Users.Student
    belongs_to :college_ug, Dbservice.Colleges.College, foreign_key: :college_id_ug
    belongs_to :college_pg, Dbservice.Colleges.College, foreign_key: :college_id_pg
    belongs_to :branch_ug, Dbservice.Branches.Branch, foreign_key: :branch_id_ug
    belongs_to :branch_pg, Dbservice.Branches.Branch, foreign_key: :branch_id_pg

    timestamps()
  end

  @doc false
  def changeset(alumni, attrs) do
    alumni
    |> cast(attrs, [
      :student_id,
      :which_competitive_exam_did_you_appear_for,
      :did_you_take_a_gap_year,
      :why_did_you_take_a_gap_year,
      :if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for,
      :start_year_ug,
      :college_id_ug,
      :degree_ug,
      :branch_id_ug,
      :year_of_graduation_ug,
      :start_year_pg,
      :college_id_pg,
      :degree_pg,
      :branch_id_pg,
      :year_of_graduation_pg,
      :past_internship_orgs,
      :which_year_did_you_start_working,
      :starting_ctc_ug_range,
      :current_ctc,
      :current_ctc_range,
      :current_job_city,
      :current_job_role,
      :current_job_sector,
      :current_org_name,
      :years_of_experience,
      :linkedin_profile_link,
      :what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job,
      :ug_status,
      :pg_status,
      :employment_status,
      :seeking_employment,
      :contact_status,
      :current_status,
      :scholarship_availed,
      :skilling_programs
    ])
    |> validate_required([:student_id])
    |> unique_constraint(:student_id)
  end
end
