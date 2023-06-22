defmodule DbserviceWeb.SwaggerSchema.User do
  @moduledoc false

  use PhoenixSwagger

  def user do
    %{
      User:
        swagger_schema do
          title("User")
          description("A user in the application")

          properties do
            full_name(:string, "Full name")
            email(:string, "Email")
            phone(:string, "Phone number")
            gender(:string, "Gender")
            address(:string, "Address")
            city(:string, "City")
            district(:string, "District")
            state(:string, "State")
            pincode(:string, "Pin code")
            role(:string, "User role")
            whatsapp_phone(:string, "Whatsapp phone")
            date_of_birth(:date, "Date of Birth")
          end

          example(%{
            full_name: "Rahul Sharma",
            email: "rahul.sharma@example.com",
            phone: "9998887777",
            gender: "Male",
            address: "Bandra Complex, Kurla Road",
            city: "Mumbai",
            district: "Mumbai",
            state: "Maharashtra",
            pincode: "400011",
            role: "student",
            whatsapp_phone: "9998887777",
            date_of_birth: "2003-08-22"
          })
        end
    }
  end

  def users do
    %{
      Users:
        swagger_schema do
          title("Users")
          description("All users in the application")
          type(:array)
          items(Schema.ref(:User))
        end
    }
  end
end
