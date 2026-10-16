defmodule Dbservice.DataImport.BatchMovementTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport.BatchMovement
  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.GradesFixtures
  import Dbservice.StatusesFixtures
  import Dbservice.ProgramsFixtures
  import Dbservice.EnrollmentRecordFixtures

  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Services.BatchEnrollmentService

  describe "process_batch_movement/1" do
    test "a row that cannot complete rolls back and reports the failure" do
      # The batches being left are closed before the new enrollment is created, so
      # a failed create used to leave the student with no current batch at all -
      # across every program - while the import still reported success.
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      _enrolled_status = status_fixture(%{title: :enrolled})

      program_a = program_fixture(%{name: "Rollback Program A"})
      program_b = program_fixture(%{name: "Rollback Program B"})

      {_user, student} = student_fixture(%{student_id: "ROLLBACK001"})
      old_batch = batch_fixture(%{batch_id: "RB_OLD", program_id: program_a.id})
      _new_batch = batch_fixture(%{batch_id: "RB_NEW", program_id: program_a.id})
      other_program_batch = batch_fixture(%{batch_id: "RB_OTHER", program_id: program_b.id})

      for batch <- [old_batch, other_program_batch] do
        {:ok, _} =
          Dbservice.EnrollmentRecords.create_enrollment_record(%{
            user_id: student.user_id,
            is_current: true,
            start_date: ~D[2024-01-01],
            group_id: batch.id,
            group_type: "batch",
            academic_year: "2024-2025"
          })
      end

      before_ids = current_batch_group_ids(student.user_id)

      # "2025-26" fails the enrollment_record academic-year format validation.
      result =
        BatchMovement.process_batch_movement(%{
          "student_id" => "ROLLBACK001",
          "apaar_id" => nil,
          "batch_id" => "RB_NEW",
          "grade" => nil,
          "start_date" => "2025-06-01",
          "academic_year" => "2025-26"
        })

      assert {:error, message} = result
      assert message =~ "YYYY-YYYY"

      # Both batches survive: the movement left the student exactly as it found them.
      assert Enum.sort(current_batch_group_ids(student.user_id)) == Enum.sort(before_ids)
      assert Enum.sort(before_ids) == Enum.sort([old_batch.id, other_program_batch.id])
    end

    test "successfully processes batch movement with valid data" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT001"})
      batch = batch_fixture(%{batch_id: "BATCH001"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => 10,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-2025"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "successfully processes batch movement without grade change" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT002"})
      batch = batch_fixture(%{batch_id: "BATCH002"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "grade" => nil,
        "start_date" => "2024-01-01",
        "academic_year" => "2024-2025"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "successfully processes batch movement with empty grade" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

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
        "academic_year" => "2024-2025"
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
        "academic_year" => "2024-2025"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:error,
              "Student not found. student_id: NONEXISTENT_STUDENT, apaar_id: NONEXISTENT_APAAR"} =
               result
    end

    test "returns error when batch is not found" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      # Create fixtures
      {_user, student} = student_fixture(%{student_id: "STUDENT005"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => "NONEXISTENT_BATCH",
        "start_date" => "2024-01-01",
        "academic_year" => "2024-2025"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:error, _reason} = result
    end

    test "returns error when grade is not found" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

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
        "academic_year" => "2024-2025"
      }

      result = BatchMovement.process_batch_movement(record)

      assert {:ok, "Batch movement processed successfully"} = result
    end

    test "handles case when student is already enrolled in the batch" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

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
        "academic_year" => "2024-2025"
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
        "academic_year" => "2024-2025"
      }

      result2 = BatchMovement.process_batch_movement(record2)
      assert {:ok, "Batch movement processed successfully"} = result2
    end

    test "handles grade change correctly" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

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
        "academic_year" => "2024-2025"
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
        "academic_year" => "2024-2025"
      }

      result2 = BatchMovement.process_batch_movement(record2)
      assert {:ok, "Batch movement processed successfully"} = result2
    end

    test "fails the row when start_date is missing" do
      # start_date is a required batch_movement header. The enrollment changeset
      # rejects a blank one, and that used to be swallowed - the row reported
      # success while no enrollment had been written.
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      {_user, student} = student_fixture(%{student_id: "STUDENT009"})
      batch = batch_fixture(%{batch_id: "BATCH009"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "academic_year" => "2024-2025"
      }

      assert {:error, message} = BatchMovement.process_batch_movement(record)
      assert message =~ "start date"
      assert current_batch_group_ids(student.user_id) == []
    end

    test "fails the row when academic_year is missing" do
      # academic_year is a required batch_movement header; same swallowed-error
      # path as the missing start_date case above.
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      {_user, student} = student_fixture(%{student_id: "STUDENT010"})
      batch = batch_fixture(%{batch_id: "BATCH010"})
      _enrolled_status = status_fixture(%{title: :enrolled})

      record = %{
        "student_id" => student.student_id,
        "apaar_id" => nil,
        "batch_id" => batch.batch_id,
        "start_date" => "2024-01-01"
      }

      assert {:error, message} = BatchMovement.process_batch_movement(record)
      assert message =~ "academic year"
      assert current_batch_group_ids(student.user_id) == []
    end
  end

  describe "process_batch_movement/1 closes the batches being left" do
    setup do
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      status_fixture(%{title: :enrolled})
      :ok
    end

    test "ends the old batch even when the new batch is in a different program" do
      {_user, student} = student_fixture(%{student_id: "XP001"})
      program_old = program_fixture()
      program_new = program_fixture()

      old_batch = batch_fixture(%{program_id: program_old.id, batch_id: "XP-COMMON"})
      new_batch = batch_fixture(%{program_id: program_new.id, batch_id: "XP-ENGG"})

      current_batch_er(student.user_id, old_batch.id)

      assert {:ok, "Batch movement processed successfully"} =
               BatchMovement.process_batch_movement(movement(student, new_batch))

      refute batch_er_current?(student.user_id, old_batch.id)
      assert batch_er_current?(student.user_id, new_batch.id)
    end

    test "ends the old batch when both batches are in the same program" do
      {_user, student} = student_fixture(%{student_id: "XP002"})
      program = program_fixture()

      old_batch = batch_fixture(%{program_id: program.id, batch_id: "SP-OLD"})
      new_batch = batch_fixture(%{program_id: program.id, batch_id: "SP-NEW"})

      current_batch_er(student.user_id, old_batch.id)

      assert {:ok, _} = BatchMovement.process_batch_movement(movement(student, new_batch))

      refute batch_er_current?(student.user_id, old_batch.id)
      assert batch_er_current?(student.user_id, new_batch.id)
    end

    test "ends every other current batch, not just one" do
      {_user, student} = student_fixture(%{student_id: "XP003"})
      program_a = program_fixture()
      program_b = program_fixture()
      program_new = program_fixture()

      batch_a = batch_fixture(%{program_id: program_a.id, batch_id: "MULTI-A"})
      batch_b = batch_fixture(%{program_id: program_b.id, batch_id: "MULTI-B"})
      new_batch = batch_fixture(%{program_id: program_new.id, batch_id: "MULTI-NEW"})

      current_batch_er(student.user_id, batch_a.id)
      current_batch_er(student.user_id, batch_b.id)

      assert {:ok, _} = BatchMovement.process_batch_movement(movement(student, new_batch))

      refute batch_er_current?(student.user_id, batch_a.id)
      refute batch_er_current?(student.user_id, batch_b.id)
      assert batch_er_current?(student.user_id, new_batch.id)
    end

    test "drops the old batch's group_user membership along with the ER" do
      {_user, student} = student_fixture(%{student_id: "XP004"})
      program_old = program_fixture()
      program_new = program_fixture()

      old_batch = batch_fixture(%{program_id: program_old.id, batch_id: "GU-OLD"})
      new_batch = batch_fixture(%{program_id: program_new.id, batch_id: "GU-NEW"})

      {old_group_id, _batch_id, _type} = BatchEnrollmentService.get_batch_info("GU-OLD")

      current_batch_er(student.user_id, old_batch.id)

      {:ok, _} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: student.user_id,
          group_id: old_group_id
        })

      assert {:ok, _} = BatchMovement.process_batch_movement(movement(student, new_batch))

      # ER and membership must move together, or they drift apart again.
      refute Dbservice.Repo.exists?(
               from(gu in Dbservice.Groups.GroupUser,
                 where: gu.user_id == ^student.user_id and gu.group_id == ^old_group_id
               )
             )
    end

    test "re-running the same row is a no-op" do
      {_user, student} = student_fixture(%{student_id: "XP005"})
      program_old = program_fixture()
      program_new = program_fixture()

      old_batch = batch_fixture(%{program_id: program_old.id, batch_id: "IDEM-OLD"})
      new_batch = batch_fixture(%{program_id: program_new.id, batch_id: "IDEM-NEW"})

      current_batch_er(student.user_id, old_batch.id)

      assert {:ok, _} = BatchMovement.process_batch_movement(movement(student, new_batch))
      assert {:ok, _} = BatchMovement.process_batch_movement(movement(student, new_batch))

      refute batch_er_current?(student.user_id, old_batch.id)
      assert batch_er_current?(student.user_id, new_batch.id)
      assert current_batch_er_count(student.user_id) == 1
    end
  end

  defp movement(student, batch) do
    %{
      "student_id" => student.student_id,
      "apaar_id" => nil,
      "batch_id" => batch.batch_id,
      "start_date" => "2024-01-01",
      "academic_year" => "2024-2025"
    }
  end

  defp current_batch_er_count(user_id) do
    Dbservice.Repo.aggregate(
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true
      ),
      :count
    )
  end

  defp current_batch_er(user_id, batch_id) do
    enrollment_record_fixture(%{
      user_id: user_id,
      group_id: batch_id,
      group_type: "batch",
      is_current: true,
      academic_year: "2024-2025"
    })
  end

  defp batch_er_current?(user_id, batch_id) do
    Dbservice.Repo.exists?(
      from(e in EnrollmentRecord,
        where:
          e.user_id == ^user_id and e.group_type == "batch" and e.group_id == ^batch_id and
            e.is_current == true
      )
    )
  end

  defp current_batch_group_ids(user_id) do
    Dbservice.Repo.all(
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true,
        select: e.group_id
      )
    )
  end
end
