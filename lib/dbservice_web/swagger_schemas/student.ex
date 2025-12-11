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
            time_of_device_availability(:string, "Time of device availability for a student")
            has_internet_access(:string, "If the family has internet access")
            primary_smartphone_owner(:string, "Primary smartphone owner")
            primary_smartphone_owner_profession(:string, "Profession of primary smartphone owner")

            board_stream(
              :string,
              "Stream or subjects chosen for the board (e.g., PCB, PCM, Commerce, Arts)"
            )

            school_medium(:string, "Medium of student's school")
            apaar_id(:string, "APAAR ID of a student")
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
            has_internet_access: "Yes",
            primary_smartphone_owner: "Father",
            primary_smartphone_owner_profession: "Employed",
            board_stream: "PCM",
            school_medium: "Hindi",
            apaar_id: "123456789101"
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
            apaar_id(:string, "APAAR ID of a student")
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
            },
            apaar_id: "123456789101"
          })
        end
    }
  end

  def student_id_generation do
    %{
      StudentIdGeneration:
        swagger_schema do
          title("Student ID Generation")
          description("Details required to generate a student ID")

          properties do
            first_name(:string, "First name", required: true)
            date_of_birth(:string, "Date of birth", format: "date", required: true)
            gender(:string, "Gender", required: true)
            category(:string, "Category", required: true)
            grade(:integer, "Grade", required: true)
            region(:string, "Region", required: true)
            school_name(:string, "School name", required: true)
          end

          example(%{
            first_name: "Rahul",
            date_of_birth: "2003-04-17",
            gender: "Male",
            category: "OBC",
            grade: 12,
            region: "Bhopal",
            school_name: "JNV Durg"
          })
        end
    }
  end

  def student_id_generation_response do
    %{
      StudentIdGenerationResponse:
        swagger_schema do
          title("Student ID Generation Response")
          description("Response after generating a student ID")

          properties do
            student_id(:string, "Generated student ID", required: true)
          end

          example(%{
            student_id: "2410505647"
          })
        end
    }
  end

  def verification_params do
    %{
      VerificationParams:
        swagger_schema do
          title("Verification Parameters")
          description("Parameters to verify against")
          type(:object)

          properties do
            auth_group_id(:integer, "Auth Group ID")
            date_of_birth(:string, "Date of Birth", format: "date")
          end

          required([:auth_group_id])

          example(%{
            auth_group_id: 2,
            date_of_birth: "2003-04-17"
          })
        end
    }
  end

  def verification_result do
    %{
      VerificationResult:
        swagger_schema do
          title("Verification Result")
          description("Result of the student verification")
          type(:object)

          properties do
            is_verified(:boolean, "Verification status")
          end

          required([:is_verified])

          example(%{
            is_verified: true
          })
        end
    }
  end

  def verify_student_request do
    %{
      VerifyStudentRequest:
        swagger_schema do
          title("Verify Student Request")
          description("Request body for verifying a student")
          type(:object)

          properties do
            student_id(:string, "Student ID")
            verification_params(Schema.ref(:VerificationParams))
          end

          required([:student_id, :verification_params])

          example(%{
            student_id: "20190240808",
            verification_params: %{
              auth_group_id: 2,
              date_of_birth: "2007-01-09"
            }
          })
        end
    }
  end

  def student_with_enrollments do
    %{
      StudentWithEnrollments:
        swagger_schema do
          title("Student with Enrollments")
          description("Student data including user information and enrollment fields")

          properties do
            # Student fields
            student_id(:string, "Unique student identifier", required: false)
            apaar_id(:string, "APAAR ID for the student", required: false)
            category(:string, "Student category (e.g., General, OBC, SC, ST)", required: false)
            status(:string, "Student status", required: false)

            # User fields
            first_name(:string, "First name", required: true)
            middle_name(:string, "Middle name", required: false)
            last_name(:string, "Last name", required: false)
            phone(:string, "Phone number", required: false)
            email(:string, "Email address", required: false)
            date_of_birth(:string, "Date of birth (YYYY-MM-DD)", format: :date, required: false)
            gender(:string, "Gender", required: false)
            father_name(:string, "Father's name", required: false)
            mother_name(:string, "Mother's name", required: false)

            # Enrollment fields
            auth_group(:string, "Auth group name", required: false)
            school_code(:string, "School code", required: false)
            batch_id(:string, "Batch ID", required: false)
            grade(:integer, "Grade number", required: false)
            grade_id(:integer, "Grade ID (alternative to grade number)", required: false)
            academic_year(:string, "Academic year (e.g., 2024-25)", required: true)

            start_date(:string, "Enrollment start date (YYYY-MM-DD)",
              format: :date,
              required: true
            )
          end

          example(%{
            first_name: "John",
            last_name: "Doe",
            date_of_birth: "2005-05-15",
            gender: "Male",
            student_id: "STU12345",
            category: "Gen",
            auth_group: "EnableStudents",
            school_code: "19062",
            batch_id: "EN-11-Photon-Eng-24",
            grade: 11,
            academic_year: "2025-2026",
            start_date: "2025-04-01"
          })
        end
    }
  end
end
