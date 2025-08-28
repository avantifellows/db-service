defmodule DbserviceWeb.SwaggerSchema.Candidate do
  @moduledoc false

  use PhoenixSwagger

  def candidate do
    %{
      Candidate:
        swagger_schema do
          title("Candidate")
          description("A candidate in the application")

          properties do
            id(:integer, "Candidate record ID")
            degree(:string, "Degree of the candidate")
            college_name(:string, "Name of the college")
            branch_name(:string, "Name of the branch")
            latest_cgpa(:number, "Latest CGPA of the candidate")
            subject_id(:integer, "Subject ID associated with the candidate")
            candidate_id(:string, "Unique candidate ID")
            user_id(:integer, "User ID for the candidate")
            user(:object, "User details associated with the candidate")
          end

          example(%{
            id: 1,
            degree: "Bachelor of Technology",
            college_name: "IIT Delhi",
            branch_name: "Computer Science",
            latest_cgpa: 8.5,
            subject_id: 2,
            candidate_id: "CAND001",
            user_id: 1,
            user: %{
              id: 1,
              first_name: "John",
              last_name: "Doe",
              email: "john.doe@example.com",
              phone: "1234567890",
              gender: "Male",
              address: "123 Main St",
              city: "Mumbai",
              district: "Mumbai",
              state: "Maharashtra",
              region: "West",
              pincode: "400001",
              role: "candidate",
              whatsapp_phone: "1234567890",
              date_of_birth: "1995-01-01",
              country: "India"
            }
          })
        end
    }
  end

  def candidates do
    %{
      Candidates:
        swagger_schema do
          title("Candidates")
          description("All candidates in the application")
          type(:array)
          items(Schema.ref(:Candidate))
        end
    }
  end
end
