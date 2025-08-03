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
            id(:integer, "Teacher record ID")
            designation(:string, "Designation of the teacher")
            teacher_id(:string, "Unique teacher ID")
            subject_id(:integer, "Subject ID associated with the teacher")
            is_af_teacher(:boolean, "Indicates whether the teacher is an AF teacher or not")
            user_id(:integer, "User ID for the teacher")
            user(:object, "User details associated with the teacher")
          end

          example(%{
            id: 1,
            designation: "Vice Principal",
            teacher_id: "3bc6b53e7bbbc883b9ab",
            subject_id: 2,
            is_af_teacher: true,
            user_id: 1,
            user: %{
              id: 1,
              first_name: "Michael",
              last_name: "Chen",
              email: "michael.chen@example.com",
              phone: "1234567890",
              gender: "Male",
              address: "123 Main St",
              city: "Mumbai",
              district: "Mumbai",
              state: "Maharashtra",
              region: "West",
              pincode: "400001",
              role: "teacher",
              whatsapp_phone: "1234567890",
              date_of_birth: "1980-01-01",
              country: "India"
            }
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

  def teacher_with_user do
    %{
      TeacherWithUser:
        swagger_schema do
          title("Teacher with User")
          description("Input for creating a teacher along with user details")

          properties do
            designation(:string, "Designation for the teacher")
            teacher_id(:string, "ID of the teacher")
            subject_id(:integer, "Subject ID associated with the teacher")
            is_af_teacher(:boolean, "Indicates whether the teacher is an AF teacher or not")
            first_name(:string, "User's first name")
            last_name(:string, "User's last name")
            email(:string, "User's email address")
            phone(:string, "User's phone number")
            gender(:string, "User's gender")
            address(:string, "User's address")
            city(:string, "User's city")
            district(:string, "User's district")
            state(:string, "User's state")
            region(:string, "User's region")
            pincode(:string, "User's pincode")
            role(:string, "User's role")
            whatsapp_phone(:string, "User's WhatsApp phone number")
            date_of_birth(:string, "User's date of birth")
            country(:string, "User's country")
          end

          example(%{
            designation: "Principal",
            teacher_id: "AF419",
            subject_id: 2,
            is_af_teacher: true,
            first_name: "Sarah",
            last_name: "Johnson",
            email: "sarah.johnson@example.com",
            phone: "9876543210",
            gender: "Female",
            address: "456 Oak Street",
            city: "Delhi",
            district: "New Delhi",
            state: "Delhi",
            region: "North",
            pincode: "110001",
            role: "principal",
            whatsapp_phone: "9876543210",
            date_of_birth: "1985-05-15",
            country: "India"
          })
        end
    }
  end

  def teacher_batch_assignment do
    %{
      TeacherBatchAssignment:
        swagger_schema do
          title("Teacher Batch Assignment")
          description("Teacher batch assignment details")

          properties do
            teacher_id(:string, "ID of the teacher to assign", required: true)
            batch_id(:string, "ID of the batch to assign the teacher to", required: true)
            start_date(:string, "Start date for the assignment", required: true)
            academic_year(:string, "Academic year for the assignment", required: true)
          end

          example(%{
            teacher_id: "AF419",
            batch_id: "BATCH001",
            start_date: "2024-01-01",
            academic_year: "2024-2025"
          })
        end
    }
  end
end
