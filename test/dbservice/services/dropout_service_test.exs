defmodule Dbservice.Services.DropoutServiceTest do
  use Dbservice.DataCase

  alias Dbservice.EnrollmentRecords
  alias Dbservice.Repo
  alias Dbservice.Services.DropoutService
  alias Dbservice.Users.Student

  import Dbservice.UsersFixtures

  defp setup_dropout_status do
    # create_status auto-creates the matching "status" group (child_id == status.id)
    # via the has_many :group assoc, which is what get_dropout_status_info joins on.
    {:ok, status} = Dbservice.Statuses.create_status(%{"title" => :dropout})
    status
  end

  defp current_batch_enrollment(user_id, academic_year) do
    {:ok, enrollment} =
      EnrollmentRecords.create_enrollment_record(%{
        "user_id" => user_id,
        "is_current" => true,
        "start_date" => ~D[2026-04-01],
        "group_id" => 999,
        "group_type" => "batch",
        "academic_year" => academic_year
      })

    enrollment
  end

  defp student_status(student_id), do: Repo.get!(Student, student_id).status

  describe "process_dropout/3 academic year validation" do
    test "blocks a dropout whose academic year does not match the current enrollment" do
      {_user, student} = student_fixture()
      current_batch_enrollment(student.user_id, "2026-2027")

      assert {:error, message} =
               DropoutService.process_dropout(student, ~D[2025-06-01], "2025-2026")

      assert message =~ "Academic year mismatch"
      # No dropout was written; the student stays as-is.
      refute student_status(student.id) == "dropout"
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
end
