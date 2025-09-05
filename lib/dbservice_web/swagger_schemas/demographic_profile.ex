defmodule DbserviceWeb.SwaggerSchema.DemographicProfile do
  @moduledoc false

  use PhoenixSwagger

  def demographic_profile do
    %{
      DemographicProfile:
        swagger_schema do
          title("DemographicProfile")
          description("A demographic profile in the application")

          properties do
            category_id(:integer, "The category ID")
            gender(:string, "Gender")
            caste(:string, "Caste")
            physically_handicapped(:boolean, "Person with Disability")
            family_income(:string, "Family income level")
            religion(:string, "Religion")
            defence_ward(:string, "Defence ward")
            nationality(:string, "Nationality")
            ews_ward(:string, "Economically Weaker Section ward")
            language(:string, "Language")
            urban_rural(:boolean, "Urban (true) or Rural (false)")
            region(:string, "Region")
          end

          example(%{
            category_id: 1,
            gender: "Male",
            caste: "General",
            physically_handicapped: false,
            family_income: "5-10 Lakhs",
            religion: "Hindu",
            defence_ward: "No",
            nationality: "Indian",
            ews_ward: "No",
            language: "English",
            urban_rural: true,
            region: "North"
          })
        end
    }
  end

  def demographic_profiles do
    %{
      DemographicProfiles:
        swagger_schema do
          title("DemographicProfiles")
          description("All the demographic profiles")
          type(:array)
          items(Schema.ref(:DemographicProfile))
        end
    }
  end
end
