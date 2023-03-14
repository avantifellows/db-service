defmodule DbserviceWeb.SwaggerSchema.Teacher do
  @moduledoc false

  use PhoenixSwagger

  def teacher do
    %{
      Teacher:
        swagger_schema do
          title("Teacher")
          description("A teacher in the application")

          properties do
            designation(:string, "Designation")
            subject(:string, "Core subject")
            grade(:string, "Grade")
            user_id(:integer, "User ID for the teacher")
            school_id(:integer, "School ID for the teacher")
            program_manager_id(:integer, "Program manager user ID for the teacher")
            uuid(:string, "UUID for the teacher")
          end

          example(%{
            designation: "Vice Principal",
            subject: "Mats",
            grade: "12",
            user_id: 1,
            school_id: 2,
            program_manager_id: 3,
            uuid: "3bc6b53e7bbbc883b9ab"
          })
        end
    }
  end

  def teachers do
    %{
      Teachers:
        swagger_schema do
          title("Teachers")
          description("All teachers in the application")
          type(:array)
          items(Schema.ref(:Teacher))
        end
    }
  end

  def teacher_registration do
    %{
      TeacherRegistration:
        swagger_schema do
          title("Teacher Registration")
          description("A teacher in the application along with user info")

          properties do
            designation(:string, "Designation for the teacher")
            grade(:string, "Grade level in which a teacher instructs")
            subject(:string, "Subject taught by the teacher")
            uuid(:string, "UUID of the teacher")
            school_id(:integer, "ID of the school associated with the teacher")
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
          end

          example(%{
            designation: "Principal",
            grade: "High School",
            uuid: "AF419",
            category: "general",
            stream: "PCB",
            full_name: "Aman Bahuguna",
            email: "aman.bahuguna@example.com",
            school_id: 2,
            phone: "8484515848",
            gender: "Male",
            address: "Bandra Complex, Kurla Road",
            city: "Mumbai",
            district: "Mumbai",
            state: "Maharashtra",
            pincode: "400011",
            role: "principal"
          })
        end
    }
  end

  def teacher_with_user do
    %{
      TeacherWithUser:
        swagger_schema do
          title("Teacher with User")
          description("A teacher in the application along with user info")

          properties do
            designation(:string, "Designation for the teacher")
            grade(:string, "Grade level in which a teacher instructs")
            subject(:string, "Subject taught by the teacher")
            uuid(:string, "UUID of the teacher")
            user(:map, "User details associated with the teacher")
          end

          example(%{
            designation: "Principal",
            grade: "High School",
            uuid: "AF419",
            category: "general",
            stream: "PCB",
            school_id: 2,
            user: %{
              full_name: "Aman Bahuguna",
              email: "aman.bahuguna@example.com",
              phone: "8484515848",
              gender: "Male",
              address: "Bandra Complex, Kurla Road",
              city: "Mumbai",
              district: "Mumbai",
              state: "Maharashtra",
              pincode: "400011",
              role: "principal"
            }
          })
        end
    }
  end
end
