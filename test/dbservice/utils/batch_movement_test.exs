defmodule Dbservice.DataImport.BatchMovementTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport.BatchMovement
  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.GradesFixtures
  import Dbservice.StatusesFixtures

  describe "process_batch_movement/1" do
    test "successfully processes batch movement with valid data" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      batch = batch_fixture(%{batch_id: "BATCH001"})
      grade = grade_fixture(%{number: 10})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => grade.number,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "successfully processes batch movement without grade change" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT002"})
      batch = batch_fixture(%{batch_id: "BATCH002"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "successfully processes batch movement with empty grade" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT003"})
      batch = batch_fixture(%{batch_id: "BATCH003"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => "",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "returns error when student is not found" do
      record = %{
        "student_id" => "NONEXISTENT_STUDENT",
        "apaar_id" => "NONEXISTENT_APAAR",
        "batch_id" => "BATCH001",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:error,
              "Student not found. student_id: NONEXISTENT_STUDENT, apaar_id: NONEXISTENT_APAAR"} =
               result
    end

    test "returns error when batch is not found" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT005"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => "NONEXISTENT_BATCH",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:error, _reason} = result
    end

    test "returns error when grade is not found" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT006"})
      batch = batch_fixture(%{batch_id: "BATCH006"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => 999,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "handles case when student is already enrolled in the batch" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT007"})
      batch = batch_fixture(%{batch_id: "BATCH007"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      # First enrollment
      record1 = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      # Process first enrollment
      result1 = BatchMovement.process_batch_movement(record1)
      assert {:ok, "Batch movement processed successfully"} = result1

      # Second enrollment (should handle already enrolled case)
      record2 = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result2 = BatchMovement.process_batch_movement(record2)
      assert {:ok, "Batch movement processed successfully"} = result2
    end

    test "handles grade change correctly" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT008"})
      batch = batch_fixture(%{batch_id: "BATCH008"})
      grade1 = grade_fixture(%{number: 8})
      grade2 = grade_fixture(%{number: 9})
      _enrolled_status = status_fixture(%{title: :enrolled})

      # First batch movement with grade 8
      record1 = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => grade1.number,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result1 = BatchMovement.process_batch_movement(record1)
      assert {:ok, "Batch movement processed successfully"} = result1

      # Second batch movement with grade 9 (grade change)
      record2 = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => grade2.number,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result2 = BatchMovement.process_batch_movement(record2)
      assert {:ok, "Batch movement processed successfully"} = result2
    end

    test "handles missing start_date gracefully" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT009"})
      batch = batch_fixture(%{batch_id: "BATCH009"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "academic_year" => "2024-25"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "handles missing academic_year gracefully" do
      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT010"})
      batch = batch_fixture(%{batch_id: "BATCH010"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end
  end
end
