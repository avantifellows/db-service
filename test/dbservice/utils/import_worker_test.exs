defmodule Dbservice.DataImport.ImportWorkerTest do
  use Dbservice.DataCase
  use Oban.Testing, repo: Dbservice.Repo

  alias Dbservice.DataImport.ImportWorker
  alias Dbservice.DataImport
  alias Dbservice.Users
  import Dbservice.DataImportFixtures
  import Dbservice.UsersFixtures

  setup do
    # Create required entities for the test
    auth_group = create_test_auth_group()
    school = create_test_school()
    grade = create_test_grade()
    batch = create_test_batch()

    # Clean up any existing test files
    on_exit(fn ->
      cleanup_test_csv("test_student_import.csv")
      cleanup_test_csv("invalid_student_import.csv")
    end)

    # Store IDs for use in CSV content
    %{
      auth_group_id: auth_group.id,
      school_id: school.id,
      grade_id: grade.id,
      batch_id: batch.id
    }
  end

  describe "perform/1" do
    test "processes a successful student import", %{
      auth_group_id: auth_group_id,
      school_id: school_id,
      grade_id: grade_id,
      batch_id: batch_id
    } do
      # Get the created entities to access their field values
      auth_group = Dbservice.AuthGroups.get_auth_group!(auth_group_id)
      school = Dbservice.Schools.get_school!(school_id)
      grade = Dbservice.Grades.get_grade(grade_id)
      batch = Dbservice.Batches.get_batch!(batch_id)

      # Create test CSV file with actual entity field values
      # Use: auth_group.name, school.code, grade.number, batch.batch_id
      csv_content =
        valid_student_csv_content(auth_group.name, school.code, grade.number, batch.batch_id)

      filename = create_test_csv("test_student_import.csv", csv_content)

      # Create import record
      import_record =
        import_fixture(%{
          filename: filename,
          type: "student",
          status: "pending"
        })

      # Create the Oban job
      job = %Oban.Job{args: %{"id" => import_record.id}}

      # Execute the worker
      assert :ok = perform_job(ImportWorker, job.args)

      # Verify import was processed
      updated_import = DataImport.get_import!(import_record.id)
      assert updated_import.status in ["completed", "processing"]
      assert updated_import.total_rows > 0

      # Validate that students were actually created by searching for them
      student1 = Users.get_student_by_student_id("STU001")
      student2 = Users.get_student_by_student_id("STU002")

      assert student1 != nil, "Student with ID STU001 should be created"
      assert student2 != nil, "Student with ID STU002 should be created"

      # Verify student details match CSV data
      assert student1.student_id == "STU001"
      assert student2.student_id == "STU002"

      # Verify associated user records exist and have correct data
      user1 = Users.get_user!(student1.user_id)
      user2 = Users.get_user!(student2.user_id)
      assert user1.first_name == "John"
      assert user1.last_name == "Doe"
      assert user1.email == "john.doe@email.com"

      assert user2.first_name == "Jane"
      assert user2.last_name == "Smith"
      assert user2.email == "jane.smith@email.com"
    end

    test "handles import with invalid data gracefully" do
      # Create test CSV file with invalid data
      csv_content = invalid_student_csv_content()
      filename = create_test_csv("invalid_student_import.csv", csv_content)

      # Create import record
      import_record =
        import_fixture(%{
          filename: filename,
          type: "student",
          status: "pending"
        })

      # Create the Oban job
      job = %Oban.Job{args: %{"id" => import_record.id}}

      # Execute the worker
      result = perform_job(ImportWorker, job.args)

      # Verify import handled errors
      updated_import = DataImport.get_import!(import_record.id)

      # Should complete but with errors recorded
      assert updated_import.error_count > 0
      assert length(updated_import.error_details) > 0

      # Verify error messages are readable
      first_error = List.first(updated_import.error_details)
      assert is_map(first_error)
      assert Map.has_key?(first_error, "row")
      assert Map.has_key?(first_error, "error")
    end

    test "fails gracefully with non-existent import" do
      job = %Oban.Job{args: %{"id" => 99999}}

      assert_raise Ecto.NoResultsError, fn ->
        perform_job(ImportWorker, job.args)
      end
    end

    test "handles unsupported import type" do
      # Create a test CSV file first
      csv_content = "header1,header2\nvalue1,value2"
      filename = create_test_csv("test.csv", csv_content)

      import_record =
        import_fixture(%{
          type: "unsupported_type",
          filename: filename
        })

      job = %Oban.Job{args: %{"id" => import_record.id}}

      assert {:error, "Unsupported import type"} = perform_job(ImportWorker, job.args)
    end
  end

  describe "CSV processing" do
    test "correctly counts total rows" do
      csv_content = """
      header1,header2,header3
      row1_col1,row1_col2,row1_col3
      row2_col1,row2_col2,row2_col3
      row3_col1,row3_col2,row3_col3
      """

      filename = create_test_csv("count_test.csv", csv_content)

      import_record =
        import_fixture(%{
          filename: filename,
          type: "student",
          start_row: 2
        })

      job = %Oban.Job{args: %{"id" => import_record.id}}

      # This will initialize and count rows
      perform_job(ImportWorker, job.args)

      updated_import = DataImport.get_import!(import_record.id)
      # Should count 3 data rows
      assert updated_import.total_rows == 3

      cleanup_test_csv("count_test.csv")
    end

    test "handles CSV with different start rows" do
      csv_content = """
      metadata_row
      header1,header2,header3
      row1_col1,row1_col2,row1_col3
      row2_col1,row2_col2,row2_col3
      """

      filename = create_test_csv("start_row_test.csv", csv_content)

      import_record =
        import_fixture(%{
          filename: filename,
          type: "student",
          # Skip metadata and header
          start_row: 3
        })

      job = %Oban.Job{args: %{"id" => import_record.id}}
      perform_job(ImportWorker, job.args)

      updated_import = DataImport.get_import!(import_record.id)
      # Should process from row 3 onwards
      assert updated_import.total_rows == 2

      cleanup_test_csv("start_row_test.csv")
    end
  end

  # describe "error formatting" do
  #   test "formats changeset errors with row numbers" do
  #     # This test would require mocking the user creation to return a changeset error
  #     # For now, we'll test the concept by examining error_details structure

  #     csv_content = invalid_student_csv_content()
  #     filename = create_test_csv("error_format_test.csv", csv_content)

  #     import_record =
  #       import_fixture(%{
  #         filename: filename,
  #         type: "student"
  #       })

  #     job = %Oban.Job{args: %{"id" => import_record.id}}
  #     perform_job(ImportWorker, job.args)

  #     updated_import = DataImport.get_import!(import_record.id)

  #     if updated_import.error_count > 0 do
  #       error = List.first(updated_import.error_details)

  #       # Verify error has row number and readable message
  #       assert Map.has_key?(error, :row)
  #       assert Map.has_key?(error, :error)
  #       assert is_integer(error.row)
  #       assert String.contains?(error.error, "Row #{error.row}:")
  #     end

  #     cleanup_test_csv("error_format_test.csv")
  #   end
  # end

  # Helper functions to create test entities
  defp create_test_auth_group do
    {:ok, auth_group} =
      Dbservice.AuthGroups.create_auth_group(%{
        name: "TEST_AUTH_GROUP"
      })

    auth_group
  end

  defp create_test_school do
    {:ok, school} =
      Dbservice.Schools.create_school(%{
        code: "TEST_SCH_001",
        name: "Test School",
        udise_code: "TEST_UDISE_001",
        gender_type: "Co-Ed",
        af_school_category: "Test Category",
        region: "Test Region",
        state_code: "TS",
        state: "Test State",
        district_code: "TST",
        district: "Test District",
        block_code: "TB001",
        block_name: "Test Block",
        board: "CBSE"
      })

    school
  end

  defp create_test_grade do
    {:ok, grade} =
      Dbservice.Grades.create_grade(%{
        number: 11
      })

    grade
  end

  defp create_test_batch do
    {:ok, batch} =
      Dbservice.Batches.create_batch(%{
        name: "Test Batch",
        batch_id: "TEST_BATCH_001",
        start_date: ~D[2023-06-15],
        af_medium: "online"
      })

    batch
  end
end
