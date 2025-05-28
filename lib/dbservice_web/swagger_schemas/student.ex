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

            school_medium(:school_medium, "Medium of student's school")
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
            school_medium: "Hindi"
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

            board_stream(
              :string,
              "Stream or subjects chosen for the board (e.g., PCB, PCM, Commerce, Arts)"
            )
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
            role: "student",
            board_stream: "PCM"
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
end
