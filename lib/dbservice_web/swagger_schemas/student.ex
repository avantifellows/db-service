defmodule DbserviceWeb.SwaggerSchema.Student do
  @moduledoc false

  use PhoenixSwagger

  def student do
    %{
      Student:
        swagger_schema do
          title("Student")
          description("A student in the application")

          properties do
            uuid(:string, "UUID for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            user_id(:integer, "User ID for the student")
            group_id(:integer, "Group ID for the student")
          end

          example(%{
            uuid: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
            user_id: 1,
            group_id: 2
          })
        end
    }
  end

  def students do
    %{
      Students:
        swagger_schema do
          title("Students")
          description("All students in the application")
          type(:array)
          items(Schema.ref(:Student))
        end
    }
  end

  def student_registration do
    %{
      StudentRegistration:
        swagger_schema do
          title("Student Registration")
          description("A student in the application along with user info")

          properties do
            uuid(:string, "UUID for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            group_id(:integer, "Group ID for the student")
            first_name(:string, "First name")
            last_name(:string, "Last name")
            email(:string, "Email")
            phone(:string, "Phone number")
            gender(:string, "Gender")
            address(:string, "Address")
            city(:string, "City")
            district(:string, "District")
            state(:string, "State")
            pincode(:string, "Pin code")
            role(:string, "User role")
          end

          example(%{
            uuid: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
            group_id: 2,
            first_name: "Rahul",
            last_name: "Sharma",
            email: "rahul.sharma@example.com",
            phone: "9998887777",
            gender: "Male",
            address: "Bandra Complex, Kurla Road",
            city: "Mumbai",
            district: "Mumbai",
            state: "Maharashtra",
            pincode: "400011",
            role: "student"
          })
        end
    }
  end

  def student_with_user do
    %{
      StudentWithUser:
        swagger_schema do
          title("Student with User")
          description("A student in the application along with user info")

          properties do
            uuid(:string, "UUID for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            group_id(:integer, "Group ID for the student")
            user(:map, "User details associated with the student")
          end

          example(%{
            uuid: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
            group_id: 2,
            user: %{
              first_name: "Rahul",
              last_name: "Sharma",
              email: "rahul.sharma@example.com",
              phone: "9998887777",
              gender: "Male",
              address: "Bandra Complex, Kurla Road",
              city: "Mumbai",
              district: "Mumbai",
              state: "Maharashtra",
              pincode: "400011",
              role: "student"
            }
          })
        end
    }
  end
end
