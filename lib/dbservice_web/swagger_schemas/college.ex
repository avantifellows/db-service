defmodule DbserviceWeb.SwaggerSchema.College do
  @moduledoc false

  use PhoenixSwagger

  def college do
    %{
      College:
        swagger_schema do
          title("College")
          description("A college in the application")

          properties do
            college_id(:string, "The unique ID of the college")
            name(:string, "The name of the college")
            state(:string, "State where the college is located")
            address(:string, "Address of the college")
            district_code(:string, "District code")
            gender_type(:string, "Gender type")
            college_type(:string, "Type of college")
            management_type(:string, "Type of management")
            year_established(:integer, "Year established")
            affiliated_to(:string, "Affiliated to")
            tuition_fee(:number, "Tuition fee", format: :decimal)
            af_hierarchy(:number, "AF hierarchy", format: :decimal)
            expected_salary(:number, "Expected salary", format: :decimal)
            salary_tier(:string, "Salary tier")
            qualifying_exam(:string, "Qualifying exam")
            nirf_ranking(:integer, "NIRF ranking")
            top_200_nirf(:boolean, "Is in top 200 NIRF")
          end

          example(%{
            college_id: "COL123",
            name: "IIT Bombay",
            state: "Maharashtra",
            address: "Powai, Mumbai",
            district_code: "MUM",
            gender_type: "Co-ed",
            college_type: "Engineering",
            management_type: "Government",
            year_established: 1958,
            affiliated_to: "Autonomous",
            tuition_fee: 200_000.00,
            af_hierarchy: 1.0,
            expected_salary: 1_800_000.00,
            salary_tier: "A",
            qualifying_exam: "JEE Advanced",
            nirf_ranking: 3,
            top_200_nirf: true
          })
        end
    }
  end

  def colleges do
    %{
      Colleges:
        swagger_schema do
          title("Colleges")
          description("All the colleges")
          type(:array)
          items(Schema.ref(:College))
        end
    }
  end
end
