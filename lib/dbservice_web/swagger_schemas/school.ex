defmodule DbserviceWeb.SwaggerSchema.School do
  @moduledoc false

  use PhoenixSwagger

  def school do
    %{
      School:
        swagger_schema do
          title("School")
          description("A school in the application")

          properties do
            code(:string, "Code")
            name(:string, "Name")
            udise_code(:string, "Udise Code")
            type(:string, "Type")
            category(:string, "Category")
            region(:string, "Region")
            state_code(:string, "State Code")
            state(:string, "State")
            district_code(:string, "District Code")
            district(:string, "District")
            block_code(:string, "Block Code")
            block_name(:string, "Block Name")
            board(:string, "Board")
            # board_medium(:string, "Medium")
            user_id(:integer, "User ID of a school")
            program_ids(:array, "Array of program IDs this school belongs to")
            school_email(:string, "Official email ID of the school")
            principal_incharge_name(:string, "Full name of the principal or in-charge")

            principal_incharge_contact(
              :string,
              "Contact number of the principal or in-charge, digits only"
            )

            pmu_coordinator_name(:string, "Full name of the PMU school coordinator")
            pmu_coordinator_contact(:string, "Contact number of the PMU school coordinator")

            school_support_status(
              :string,
              "How supportive the school is - Supportive, Non-Supportive or Neutral"
            )

            school_residential_status(:string, "Residential or Non-Residential")

            grades_offered(
              :array,
              "Grades the school runs, 1 to 12, e.g. [6, 7, 8]; null when not surveyed yet"
            )

            school_stream(
              :array,
              "Streams the school runs - Science, Commerce, Arts (Humanities); null when not surveyed yet"
            )

            estimated_strength_grade_11(:integer, "Estimated number of students in Grade 11")
            estimated_strength_grade_12(:integer, "Estimated number of students in Grade 12")
            school_notes(:string, "Free-text remarks or observations about the school")
          end

          example(%{
            code: "872931",
            name: "Kendriya Vidyalaya - Rajori Garden",
            udise_code: "05040120901",
            type: "Open",
            category: "Government",
            region: "Urban",
            state_code: "DL",
            state: "Delhi",
            district_code: "0701",
            district: "NORTH WEST DELHI",
            block_code: "DOEAIDED",
            board: "CBSE",
            board_medium: "en",
            user_id: 1,
            program_ids: [1, 64],
            school_email: "kv.rajorigarden@example.edu.in",
            principal_incharge_name: "Sunita Rao",
            principal_incharge_contact: "9876543210",
            pmu_coordinator_name: "Imran Qureshi",
            pmu_coordinator_contact: "9123456780",
            school_support_status: "Supportive",
            school_residential_status: "Non-Residential",
            grades_offered: [6, 7, 8, 9, 10, 11, 12],
            school_stream: ["Science", "Commerce"],
            estimated_strength_grade_11: 48,
            estimated_strength_grade_12: 45,
            school_notes: "Principal has offered two rooms for after-school sessions."
          })
        end
    }
  end

  def schools do
    %{
      Schools:
        swagger_schema do
          title("Schools")
          description("All schools in the application")
          type(:array)
          items(Schema.ref(:School))
        end
    }
  end

  def schoolbatches do
    %{
      SchoolBatches:
        swagger_schema do
          title("School Batch")
          description("Relation between school and batch")

          properties do
            school_id(:integer, "Id of a particular school")
            batch_id(:integer, "Id of a particular batch")
          end

          example(%{
            school_id: 1,
            batch_id: 1
          })
        end
    }
  end
end
