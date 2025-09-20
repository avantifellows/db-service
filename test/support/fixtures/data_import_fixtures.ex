defmodule Dbservice.DataImportFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.DataImport` context.
  """

  alias Dbservice.DataImport

  @doc """
  Generate a basic import record.
  """
  def import_fixture(attrs \\ %{}) do
    {:ok, import_record} =
      attrs
      |> Enum.into(%{
        filename: "test_file.csv",
        status: "pending",
        type: "student",
        total_rows: 100,
        processed_rows: 0,
        error_count: 0,
        error_details: [],
        start_row: 2
      })
      |> DataImport.create_import()

    import_record
  end

  @doc """
  Generate an import record with processing status.
  """
  def processing_import_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:status, "processing")
    |> Map.put(:processed_rows, 25)
    |> import_fixture()
  end

  @doc """
  Generate an import record with completed status.
  """
  def completed_import_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:status, "completed")
    |> Map.put(:processed_rows, 100)
    |> Map.put(:completed_at, DateTime.utc_now())
    |> import_fixture()
  end

  @doc """
  Generate an import record with errors.
  """
  def failed_import_fixture(attrs \\ %{}) do
    error_details = [
      %{row: 3, error: "Email is invalid"},
      %{row: 5, error: "Phone number is required"}
    ]

    attrs
    |> Map.put(:status, "failed")
    |> Map.put(:error_count, 2)
    |> Map.put(:error_details, error_details)
    |> import_fixture()
  end

  @doc """
  Create a temporary CSV file for testing.
  """
  def create_test_csv(filename, content) do
    test_uploads_dir = Path.join(["priv", "static", "uploads", "test"])
    File.mkdir_p!(test_uploads_dir)

    file_path = Path.join([test_uploads_dir, filename])
    File.write!(file_path, content)

    # Return relative path as expected by the system
    Path.join(["test", filename])
  end

  @doc """
  Clean up test CSV files.
  """
  def cleanup_test_csv(filename) do
    file_path = Path.join(["priv", "static", "uploads", "test", filename])

    if File.exists?(file_path) do
      File.rm!(file_path)
    end
  end

  @doc """
  Generate valid student CSV content for testing.
  """
  def valid_student_csv_content(
        auth_group_id \\ "AUTH001",
        school_code \\ "SCH001",
        grade_number \\ 11,
        batch_id_value \\ "BATCH001"
      ) do
    """
    user_first_name,user_last_name,user_email,user_phone,user_date_of_birth,user_gender,student_id,student_category,student_stream,user_whatsapp_phone,user_address,user_city,user_district,user_state,user_pincode,student_father_name,student_father_phone,student_mother_name,student_mother_phone,student_family_income,student_father_profession,student_father_education_level,student_mother_profession,student_mother_education_level,student_time_of_device_availability,student_has_internet_access,student_primary_smartphone_owner,student_primary_smartphone_owner_profession,student_guardian_name,student_guardian_relation,student_guardian_phone,student_guardian_education_level,student_guardian_profession,student_annual_family_income,student_monthly_family_income,student_number_of_smartphones,student_family_type,student_number_of_four_wheelers,student_number_of_two_wheelers,student_goes_for_tuition_or_other_coaching,student_know_about_avanti,student_percentage_in_grade_10_science,student_percentage_in_grade_10_math,student_percentage_in_grade_10_english,student_physically_handicapped,student_has_category_certificate,student_has_air_conditioner,student_board_stream,student_school_medium,addition_date,auth_group,academic_year,grade,batch_id,school_code,school_name,start_date
    John,Doe,john.doe@email.com,9876543210,1995-05-15,Male,STU001,Gen,pcmb,9876543210,123 Main St,Delhi,New Delhi,Delhi,110001,Mr. John Sr,9876543200,Mrs. Jane Sr,9876543201,50000,Engineer,Graduate,Teacher,Graduate,Evening,,Father,Engineer,Mr. Guardian,Uncle,9876543202,Graduate,Doctor,600000,50000,2,Nuclear,1,2,,,85.5,88.0,82.5,No,Yes,Yes,CBSE,English,2023-06-15,#{auth_group_id},2023-24,#{grade_number},#{batch_id_value},#{school_code},Test School 1,2023-06-15
    Jane,Smith,jane.smith@email.com,9876543211,1996-03-20,Female,STU002,OBC,ca,9876543211,456 Oak Ave,Mumbai,Mumbai,Maharashtra,400001,Mr. Smith Sr,9876543220,Mrs. Smith Sr,9876543221,40000,Doctor,Post-Graduate,Nurse,Graduate,Morning,,Mother,Nurse,Mrs. Guardian,Aunt,9876543222,Graduate,Teacher,480000,40000,1,Joint,0,1,,,78.0,75.5,80.0,No,No,No,State Board,Hindi,2023-06-20,#{auth_group_id},2023-24,#{grade_number},#{batch_id_value},#{school_code},Test School 2,2023-06-20
    """
  end

  @doc """
  Generate invalid student CSV content for testing.
  """
  def invalid_student_csv_content(
        auth_group_id \\ "AUTH001",
        school_id \\ "SCH001",
        grade_id \\ 11,
        batch_id \\ "BATCH001"
      ) do
    """
    user_first_name,user_last_name,user_email,user_phone,user_date_of_birth,user_gender,student_id,student_category,student_stream,user_whatsapp_phone,user_address,user_city,user_district,user_state,user_pincode,student_father_name,student_father_phone,student_mother_name,student_mother_phone,student_family_income,student_father_profession,student_father_education_level,student_mother_profession,student_mother_education_level,student_time_of_device_availability,student_has_internet_access,student_primary_smartphone_owner,student_primary_smartphone_owner_profession,student_guardian_name,student_guardian_relation,student_guardian_phone,student_guardian_education_level,student_guardian_profession,student_annual_family_income,student_monthly_family_income,student_number_of_smartphones,student_family_type,student_number_of_four_wheelers,student_number_of_two_wheelers,student_goes_for_tuition_or_other_coaching,student_know_about_avanti,student_percentage_in_grade_10_science,student_percentage_in_grade_10_math,student_percentage_in_grade_10_english,student_physically_handicapped,student_has_category_certificate,student_has_air_conditioner,student_board_stream,student_school_medium,addition_date,auth_group,academic_year,grade,batch_id,school_code,school_name,start_date
    John,Doe,invalid-email,9876543210,invalid-date,Male,STU001,Gen,pcmb,9876543210,123 Main St,Delhi,New Delhi,Delhi,110001,Mr. John Sr,9876543200,Mrs. Jane Sr,9876543201,50000,Engineer,Graduate,Teacher,Graduate,Evening,Yes,Father,Engineer,Mr. Guardian,Uncle,9876543202,Graduate,Doctor,600000,50000,2,Nuclear,1,2,No,Yes,85.5,88.0,82.5,No,Yes,Yes,CBSE,English,2023-06-15,#{auth_group_id},2023-24,#{grade_id},#{batch_id},#{school_id},Test School 1,2023-06-15
    ,Smith,jane.smith@email.com,invalid-phone,1996-03-20,Female,STU002,OBC,ca,9876543211,456 Oak Ave,Mumbai,Mumbai,Maharashtra,400001,Mr. Smith Sr,9876543220,Mrs. Smith Sr,9876543221,40000,Doctor,Post-Graduate,Nurse,Graduate,Morning,Yes,Mother,Nurse,Mrs. Guardian,Aunt,9876543222,Graduate,Teacher,480000,40000,1,Joint,0,1,Yes,No,78.0,75.5,80.0,No,No,No,State Board,Hindi,2023-06-20,#{auth_group_id},2023-24,#{grade_id},#{batch_id},#{school_id},Test School 2,2023-06-20
    """
  end

  @doc """
  Generate student CSV with missing headers.
  """
  def incomplete_student_csv_content do
    """
    first_name,last_name,email
    John,Doe,john.doe@email.com
    Jane,Smith,jane.smith@email.com
    """
  end
end
