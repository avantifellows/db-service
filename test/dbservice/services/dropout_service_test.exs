defmodule Dbservice.Services.DropoutServiceTest do
  use Dbservice.DataCase

  alias Dbservice.EnrollmentRecords
  alias Dbservice.Repo
  alias Dbservice.Services.DropoutService
  alias Dbservice.Users.Student

  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.ProgramsFixtures

  defp setup_dropout_status do
    # create_status auto-creates the matching "status" group (child_id == status.id)
    # via the has_many :group assoc, which is what get_dropout_status_info joins on.
    {:ok, status} = Dbservice.Statuses.create_status(%{"title" => :dropout})
    status
  end

  defp current_batch_enrollment(user_id, academic_year, group_id \\ 999) do
    {:ok, enrollment} =
      EnrollmentRecords.create_enrollment_record(%{
        "user_id" => user_id,
        "is_current" => true,
        "start_date" => ~D[2026-04-01],
        "group_id" => group_id,
        "group_type" => "batch",
        "academic_year" => academic_year
      })

    enrollment
  end

  defp student_status(student_id), do: Repo.get!(Student, student_id).status

  describe "process_dropout/3 bulk (most-recent) academic year validation" do
    test "blocks a dropout whose academic year does not match the current enrollment" do
      {_user, student} = student_fixture()
      current_batch_enrollment(student.user_id, "2026-2027")

      assert {:error, message} =
               DropoutService.process_dropout(student, ~D[2025-06-01], "2025-2026")

      assert message =~ "Academic year mismatch"
      # No dropout was written; the student stays as-is.
      refute student_status(student.id) == "dropout"
    end

    test "blocks a year older than the student's most recent current enrollment" do
      {_user, student} = student_fixture()
      # Two current years; the bulk path validates against the most recent (2025-2026).
      current_batch_enrollment(student.user_id, "2024-2025")
      current_batch_enrollment(student.user_id, "2025-2026")

      assert {:error, message} =
               DropoutService.process_dropout(student, ~D[2025-06-01], "2024-2025")

      assert message =~ "Academic year mismatch"
    end

    test "allows a dropout whose academic year matches the current enrollment" do
      setup_dropout_status()
      {_user, student} = student_fixture()
      current_batch_enrollment(student.user_id, "2026-2027")

      assert {:ok, updated} =
               DropoutService.process_dropout(student, ~D[2026-06-01], "2026-2027")

      assert updated.status == "dropout"
    end

    test "allows a dropout when there is no academic-year enrollment to validate against" do
      setup_dropout_status()
      {_user, student} = student_fixture()

      assert {:ok, updated} =
               DropoutService.process_dropout(student, ~D[2026-06-01], "2026-2027")

      assert updated.status == "dropout"
    end
  end

  describe "process_dropout/4 program-scoped academic year validation" do
    setup do
      {_user, student} = student_fixture()

      program_a = program_fixture()
      program_b = program_fixture()

      batch_a = batch_fixture(%{program_id: program_a.id, batch_id: "BATCH-A"})
      batch_b = batch_fixture(%{program_id: program_b.id, batch_id: "BATCH-B"})

      # Two current batch enrollments in different programs / different years,
      # mirroring the multi-program student Deepansh flagged.
      current_batch_enrollment(student.user_id, "2024-2025", batch_a.id)
      current_batch_enrollment(student.user_id, "2025-2026", batch_b.id)

      audit_params = %{
        "actor" => %{"email" => "actor@example.com"},
        "school" => %{"code" => "SCH", "udise_code" => "U1"},
        "program_id" => program_b.id
      }

      %{student: student, audit_params: audit_params}
    end

    test "rejects an academic year belonging to a different program than the one being dropped",
         %{student: student, audit_params: audit_params} do
      # program_b's enrollment is 2025-2026; 2024-2025 belongs to program_a and
      # must not validate the program_b dropout.
      assert {:error, message} =
               DropoutService.process_dropout(student, ~D[2025-06-01], "2024-2025", audit_params)

      assert message =~ "Academic year mismatch"
    end

    test "accepts the target program's own academic year and moves past the AY check",
         %{student: student, audit_params: audit_params} do
      # Correct year for program_b: the AY check passes, so the request proceeds
      # to the downstream school check rather than failing on the academic year.
      assert {:error, message} =
               DropoutService.process_dropout(student, ~D[2025-06-01], "2025-2026", audit_params)

      refute message =~ "Academic year mismatch"
      assert message == "Student is not enrolled in this school"
    end
  end
end
