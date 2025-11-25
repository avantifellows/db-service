defmodule DbserviceWeb.AlumniJSON do
  def index(%{alumni: alumni}) do
    for(a <- alumni, do: render(a))
  end

  def show(%{alumni: alumni}) do
    render(alumni)
  end

  def render(alumni) do
    %{
      id: alumni.id,
      student_id: alumni.student_id,
      which_competitive_exam_did_you_appear_for: alumni.which_competitive_exam_did_you_appear_for,
      did_you_take_a_gap_year: alumni.did_you_take_a_gap_year,
      why_did_you_take_a_gap_year: alumni.why_did_you_take_a_gap_year,
      if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for:
        alumni.if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for,
      # UG fields
      start_year_ug: alumni.start_year_ug,
      college_id_ug: alumni.college_id_ug,
      degree_ug: alumni.degree_ug,
      branch_id_ug: alumni.branch_id_ug,
      year_of_graduation_ug: alumni.year_of_graduation_ug,
      # PG fields
      start_year_pg: alumni.start_year_pg,
      college_id_pg: alumni.college_id_pg,
      degree_pg: alumni.degree_pg,
      branch_id_pg: alumni.branch_id_pg,
      year_of_graduation_pg: alumni.year_of_graduation_pg,
      # Employment fields
      past_internship_orgs: alumni.past_internship_orgs,
      which_year_did_you_start_working: alumni.which_year_did_you_start_working,
      starting_ctc_ug_range: alumni.starting_ctc_ug_range,
      current_ctc: alumni.current_ctc,
      current_ctc_range: alumni.current_ctc_range,
      current_job_city: alumni.current_job_city,
      current_job_role: alumni.current_job_role,
      current_job_sector: alumni.current_job_sector,
      current_org_name: alumni.current_org_name,
      years_of_experience: alumni.years_of_experience,
      linkedin_profile_link: alumni.linkedin_profile_link,
      what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job:
        alumni.what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job,
      # Status fields
      ug_status: alumni.ug_status,
      pg_status: alumni.pg_status,
      employment_status: alumni.employment_status,
      seeking_employment: alumni.seeking_employment,
      contact_status: alumni.contact_status
    }
  end
end
