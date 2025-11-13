defmodule DbserviceWeb.SwaggerSchema.Alumni do
  use PhoenixSwagger

  def alumni do
    %{
      Alumni:
        swagger_schema do
          title("Alumni")
          description("An alumni record")

          properties do
            id(:integer, "Alumni ID")
            student_id(:integer, "Student ID", required: true)
            phone_number(:integer, "Phone number")
            email(:string, "Email address")

            which_competitive_exam_did_you_appear_for(:string, "Competitive exam appeared for")
            did_you_take_a_gap_year(:string, "Did you take a gap year")
            why_did_you_take_a_gap_year(:string, "Reason for gap year")

            if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for(
              :string,
              "Other test prep resources"
            )

            # UG fields
            start_year_ug(:integer, "UG start year")
            college_id_ug(:integer, "UG college ID")
            degree_ug(:string, "UG degree")
            branch_ug(:string, "UG branch")
            year_of_graduation_ug(:integer, "UG graduation year")

            # PG fields
            start_year_pg(:integer, "PG start year")
            college_id_pg(:integer, "PG college ID")
            degree_pg(:string, "PG degree")
            branch_pg(:string, "PG branch")
            year_of_graduation_pg(:integer, "PG graduation year")

            past_internship_orgs(:string, "Past internship organizations")
            which_year_did_you_start_working(:integer, "Year started working")
            starting_ctc_ug_range(:string, "Starting CTC range after UG")
            current_ctc(:integer, "Current CTC")
            current_ctc_range(:string, "Current CTC range")
            current_job_city(:string, "Current job city")
            current_job_role(:string, "Current job role")
            current_job_sector(:string, "Current job sector")
            current_org_name(:string, "Current organization name")
            years_of_experience(:integer, "Years of experience")
            linkedin_profile_link(:string, "LinkedIn profile link")

            what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job(
              :string,
              "Monthly household income when starting first job"
            )

            ug_status(:string, "UG status")
            pg_status(:string, "PG status")
            employment_status(:string, "Employment status")
            seeking_employment(:string, "Seeking employment")
            contact_status(:string, "Contact status")

            inserted_at(:string, "Created timestamp", format: "ISO-8601")
            updated_at(:string, "Updated timestamp", format: "ISO-8601")
          end

          example(%{
            id: 1,
            student_id: 123,
            phone_number: 9_876_543_210,
            email: "alumni@example.com",
            which_competitive_exam_did_you_appear_for: "JEE",
            did_you_take_a_gap_year: "No",
            start_year_ug: 2015,
            college_id_ug: 1,
            degree_ug: "B.Tech",
            branch_ug: "Computer Science",
            year_of_graduation_ug: 2019,
            current_job_role: "Software Engineer",
            current_org_name: "Tech Company",
            years_of_experience: 4,
            employment_status: "Employed",
            ug_status: "Completed",
            contact_status: "Active"
          })
        end
    }
  end

  def alumnis do
    %{
      Alumnis:
        swagger_schema do
          title("Alumnis")
          description("A collection of alumni records")
          type(:array)
          items(Schema.ref(:Alumni))
        end
    }
  end
end
