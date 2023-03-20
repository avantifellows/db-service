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
            student_id(:string, "Id for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            user_id(:integer, "User ID for the student")
            physically_handicapped(:boolean, "Physically hadicapped")
            family_income(:string, "Annual income of family")
            father_profession(:string, "Father's profession")
            mother_profession(:String, "Mother's profession")
            mother_education_level(:string, "Mother's education level")
            has_internet_access(:boolean, "If the family has internet access")
            primary_smartphone_owner(:string, "Primary smartphone owner")
            primary_smartphone_owner_profession(:string, "Profession of primary smartphone owner")
          end

          example(%{
            student_id: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
            user_id: 1,
            physically_handicapped: false,
            family_income: "3LPA-6LPA",
            father_profession: "Unemployed",
            father_education_level: "UG",
            mother_profession: "Housewife",
            mother_education_level: "UG",
            time_of_device_availability: "2022-10-07",
            has_internet_access: true,
            primary_smartphone_owner: "Father",
            primary_smartphone_owner_profession: "Employed"
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
            student_id(:string, "Id for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
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
            student_id: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
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
            student_id(:string, "Id for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            user(:map, "User details associated with the student")
          end

          example(%{
            student_id: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
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
