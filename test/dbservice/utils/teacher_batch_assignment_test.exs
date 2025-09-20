defmodule Dbservice.DataImport.TeacherBatchAssignmentTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport.TeacherBatchAssignment
  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.StatusesFixtures

  describe "process_teacher_batch_assignment/1" do
    test "successfully processes teacher batch assignment with valid data" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER001"})
      batch = batch_fixture(%{batch_id: "BATCH001"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = TeacherBatchAssignment.process_teacher_batch_assignment(record)

      assert {:ok, "Teacher batch assignment processed successfully"} = result
    end

    test "returns error when teacher is not found" do
      record = %{
        "teacher_id" => "NONEXISTENT_TEACHER",
        "batch_id" => "BATCH001",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = TeacherBatchAssignment.process_teacher_batch_assignment(record)

      assert {:error, "Teacher not found with ID: NONEXISTENT_TEACHER"} = result
    end

    test "returns error when batch is not found" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER002"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => "NONEXISTENT_BATCH",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result = TeacherBatchAssignment.process_teacher_batch_assignment(record)

      assert {:error, "Batch not found with ID: NONEXISTENT_BATCH"} = result
    end

    test "handles case when teacher is already assigned to the batch" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER003"})
      batch = batch_fixture(%{batch_id: "BATCH003"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      # First assignment
      record1 = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      # Process first assignment
      result1 = TeacherBatchAssignment.process_teacher_batch_assignment(record1)
      assert {:ok, "Teacher batch assignment processed successfully"} = result1

      # Second assignment (should handle already assigned case)
      record2 = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result2 = TeacherBatchAssignment.process_teacher_batch_assignment(record2)
      assert {:ok, "Teacher batch assignment processed successfully"} = result2
    end

    test "handles missing start_date gracefully" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER004"})
      batch = batch_fixture(%{batch_id: "BATCH004"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch.batch_id,
        "academic_year" => "2024-25"
      }

      result = TeacherBatchAssignment.process_teacher_batch_assignment(record)

      assert {:ok, "Teacher batch assignment processed successfully"} = result
    end

    test "handles missing academic_year gracefully" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER005"})
      batch = batch_fixture(%{batch_id: "BATCH005"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01"
      }

      result = TeacherBatchAssignment.process_teacher_batch_assignment(record)

      assert {:ok, "Teacher batch assignment processed successfully"} = result
    end

    test "processes assignment with different academic years" do
      # Create fixtures
      {_user, teacher} = teacher_fixture(%{teacher_id: "TEACHER007"})
      batch1 = batch_fixture(%{batch_id: "BATCH007A"})
      batch2 = batch_fixture(%{batch_id: "BATCH007B"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      # First assignment for 2024-25
      record1 = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch1.batch_id,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-25"
      }

      result1 = TeacherBatchAssignment.process_teacher_batch_assignment(record1)
      assert {:ok, "Teacher batch assignment processed successfully"} = result1

      # Second assignment for 2025-26
      record2 = %{
        "teacher_id" => teacher.teacher_id,
        "batch_id" => batch2.batch_id,
        "start_date" => "2025-01-01",
        "academic_year" => "2025-26"
      }

      result2 = TeacherBatchAssignment.process_teacher_batch_assignment(record2)
      assert {:ok, "Teacher batch assignment processed successfully"} = result2
    end
  end
end
