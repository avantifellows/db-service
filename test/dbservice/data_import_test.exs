defmodule Dbservice.DataImportTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport
  import Dbservice.DataImportFixtures

  describe "imports" do
    test "list_imports/0 returns all imports" do
      import_record = import_fixture()
      imports = DataImport.list_imports()
      assert length(imports) >= 1
      assert Enum.any?(imports, fn imp -> imp.id == import_record.id end)
    end

    test "get_import!/1 returns the import with given id" do
      import_record = import_fixture()
      fetched_import = DataImport.get_import!(import_record.id)
      assert fetched_import.id == import_record.id
      assert fetched_import.filename == import_record.filename
    end

    test "create_import/1 with valid data creates an import" do
      valid_attrs = %{
        filename: "test.csv",
        status: "pending",
        type: "student",
        start_row: 2
      }

      assert {:ok, import_record} = DataImport.create_import(valid_attrs)
      assert import_record.filename == "test.csv"
      assert import_record.status == "pending"
      assert import_record.type == "student"
      assert import_record.start_row == 2
    end

    test "create_import/1 with invalid data returns error changeset" do
      invalid_attrs = %{filename: nil, status: nil, type: nil}
      assert {:error, %Ecto.Changeset{}} = DataImport.create_import(invalid_attrs)
    end

    test "update_import/2 with valid data updates the import" do
      import_record = import_fixture()

      update_attrs = %{
        status: "processing",
        processed_rows: 50,
        error_count: 2
      }

      assert {:ok, updated_import} = DataImport.update_import(import_record, update_attrs)
      assert updated_import.status == "processing"
      assert updated_import.processed_rows == 50
      assert updated_import.error_count == 2
    end

    test "update_import/2 with invalid data returns error changeset" do
      import_record = import_fixture()
      invalid_attrs = %{status: nil, type: nil}

      assert {:error, %Ecto.Changeset{}} = DataImport.update_import(import_record, invalid_attrs)
      # Ensure the original record is unchanged
      refetched = DataImport.get_import!(import_record.id)
      assert refetched.status == import_record.status
    end

    test "change_import/1 returns an import changeset" do
      import_record = import_fixture()
      changeset = DataImport.change_import(import_record)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "format_type_name/1" do
    test "formats known import types correctly" do
      assert DataImport.format_type_name("student") == "Student Addition"
      assert DataImport.format_type_name("student_update") == "Update Student Details"
      assert DataImport.format_type_name("batch_movement") == "Student Batch Movement"
      assert DataImport.format_type_name("teacher_batch_assignment") == "Teacher Batch Assignment"
      assert DataImport.format_type_name("teacher_addition") == "Teacher Addition"
    end

    test "formats complex type names correctly" do
      assert DataImport.format_type_name("update_incorrect_batch_id_to_correct_batch_id") ==
               "Update Incorrect Batch ID to Correct Batch ID"

      assert DataImport.format_type_name("update_incorrect_school_to_correct_school") ==
               "Update Incorrect School to Correct School"
    end

    test "capitalizes unknown types" do
      assert DataImport.format_type_name("unknown_type") == "Unknown_type"
      assert DataImport.format_type_name("custom") == "Custom"
    end
  end

  describe "start_import/1" do
    test "fails with missing required fields" do
      invalid_params = %{
        "type" => "student",
        "start_row" => "2"
      }

      assert {:error, reason} = DataImport.start_import(invalid_params)
      assert reason =~ "URL is required"
    end

    test "fails with invalid start_row" do
      invalid_params = %{
        "sheet_url" => "https://example.com/sheet",
        "type" => "student",
        "start_row" => "invalid"
      }

      assert_raise ArgumentError, fn ->
        DataImport.start_import(invalid_params)
      end
    end

    test "fails with wrong CSV headers for import type" do
      # Create a temporary CSV file with incorrect headers for student import
      invalid_csv_content = """
      wrong_header1,wrong_header2,invalid_column
      John,Doe,test@example.com
      Jane,Smith,jane@example.com
      """

      # Create temporary file
      filename = "test_invalid_headers_#{:rand.uniform(1000)}.csv"
      upload_dir = Path.join(["priv", "static", "uploads"])
      File.mkdir_p!(upload_dir)
      file_path = Path.join([upload_dir, filename])
      File.write!(file_path, invalid_csv_content)

      # Test validation directly
      result = DataImport.validate_csv_format(filename, "student", 2)

      # Cleanup
      File.rm(file_path)

      assert {:error, reason} = result
      assert reason =~ "Invalid format for Student Addition sheet"
    end

    # Note: Testing actual Google Sheets download would require mock setup
    # This would be part of integration testing
  end

  describe "import status tracking" do
    test "tracks processing progress correctly" do
      import_record = import_fixture(%{total_rows: 100})

      # Simulate progress updates
      {:ok, updated} =
        DataImport.update_import(import_record, %{
          processed_rows: 25,
          status: "processing"
        })

      assert updated.processed_rows == 25
      assert updated.status == "processing"

      # Complete the import
      {:ok, completed} =
        DataImport.update_import(updated, %{
          processed_rows: 100,
          status: "completed",
          completed_at: DateTime.utc_now()
        })

      assert completed.processed_rows == 100
      assert completed.status == "completed"
      assert completed.completed_at != nil
    end

    test "tracks errors correctly" do
      import_record = import_fixture()

      error_details = [
        %{row: 3, error: "Invalid email format"},
        %{row: 5, error: "Missing required field"}
      ]

      {:ok, updated} =
        DataImport.update_import(import_record, %{
          error_count: 2,
          error_details: error_details,
          status: "completed_with_errors"
        })

      assert updated.error_count == 2
      assert length(updated.error_details) == 2
      assert updated.status == "completed_with_errors"
    end
  end
end
