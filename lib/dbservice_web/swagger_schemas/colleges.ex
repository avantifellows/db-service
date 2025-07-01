defmodule DbserviceWeb.SwaggerSchema.College do
  @moduledoc """
  Defines the JSON schemas for College API documentation.
  """
  
  def college do
    %{
      College: %{
        type: :object,
        properties: %{
          id: %{type: :integer, description: "College ID"},
          college_id: %{type: :string, description: "Unique college identifier"},
          institute: %{type: :string, description: "Name of the institute"},
          state: %{type: :string, description: "State where the college is located"},
          place: %{type: :string, description: "City/Town where the college is located"},
          dist_code: %{type: :string, description: "District code"},
          co_ed: %{type: :boolean, description: "Whether the college is co-educational"},
          college_type: %{type: :string, description: "Type of college (e.g., Engineering, Medical)"},
          year_established: %{type: :integer, description: "Year the college was established"},
          affiliated_to: %{type: :string, description: "University/Board the college is affiliated to"},
          tuition_fee: %{type: :number, format: "float", description: "Annual tuition fee"},
          af_hierarchy: %{type: :string, description: "Affiliation hierarchy"},
          college_ranking: %{type: :integer, description: "Current ranking of the college"},
          management_type: %{type: :string, description: "Type of management (e.g., Private, Government)"},
          expected_salary: %{type: :number, format: "float", description: "Expected salary after graduation"},
          salary_tier: %{type: :string, description: "Salary tier"},
          qualifying_exam: %{type: :string, description: "Qualifying exam for admission"},
          top_200_nirf: %{type: :boolean, description: "Whether the college is in top 200 NIRF ranking"},
          inserted_at: %{type: :string, format: "date-time", description: "Creation timestamp"},
          updated_at: %{type: :string, format: "date-time", description: "Last update timestamp"}
        },
        required: [
          :id,
          :college_id,
          :institute,
          :inserted_at,
          :updated_at
        ],
        example: %{
          id: 1,
          college_id: "COL123",
          institute: "Example University",
          state: "Maharashtra",
          place: "Mumbai",
          dist_code: "MUM",
          co_ed: true,
          college_type: "Engineering",
          year_established: 2000,
          affiliated_to: "Mumbai University",
          tuition_fee: 100000.0,
          af_hierarchy: "State",
          college_ranking: 25,
          management_type: "Private",
          expected_salary: 800000.0,
          salary_tier: "A",
          qualifying_exam: "JEE",
          top_200_nirf: true,
          inserted_at: "2023-01-01T00:00:00Z",
          updated_at: "2023-01-01T00:00:00Z"
        }
      },
      CollegeRequest: %{
        type: :object,
        properties: %{
          college: %{
            type: :object,
            properties: %{
              college_id: %{type: :string, description: "Unique college identifier"},
              institute: %{type: :string, description: "Name of the institute"},
              state: %{type: :string, description: "State where the college is located"},
              place: %{type: :string, description: "City/Town where the college is located"},
              dist_code: %{type: :string, description: "District code"},
              co_ed: %{type: :boolean, description: "Whether the college is co-educational"},
              college_type: %{type: :string, description: "Type of college (e.g., Engineering, Medical)"},
              year_established: %{type: :integer, description: "Year the college was established"},
              affiliated_to: %{type: :string, description: "University/Board the college is affiliated to"},
              tuition_fee: %{type: :number, format: "float", description: "Annual tuition fee"},
              af_hierarchy: %{type: :string, description: "Affiliation hierarchy"},
              college_ranking: %{type: :integer, description: "Current ranking of the college"},
              management_type: %{type: :string, description: "Type of management (e.g., Private, Government)"},
              expected_salary: %{type: :number, format: "float", description: "Expected salary after graduation"},
              salary_tier: %{type: :string, description: "Salary tier"},
              qualifying_exam: %{type: :string, description: "Qualifying exam for admission"},
              top_200_nirf: %{type: :boolean, description: "Whether the college is in top 200 NIRF ranking"}
            },
            required: [:institute, :state, :place]
          }
        },
        required: [:college]
      }
    }
  end
end
