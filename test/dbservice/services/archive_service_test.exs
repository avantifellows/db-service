defmodule Dbservice.Services.ArchiveServiceTest do
  use Dbservice.DataCase, async: false

  import Ecto.Query

  import Dbservice.StatusesFixtures
  import Dbservice.UsersFixtures

  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.Group
  alias Dbservice.Services.ArchiveService
  alias Dbservice.Statuses.Status
  alias Dbservice.Users

  describe "process_archive/3" do
    test "ends every current enrollment and records the archived status" do
      {_user, student} = student_fixture()
      enrolled_status = status_fixture(%{title: :enrolled})
      archived_status = archived_status()

      {:ok, current_enrollment} =
        EnrollmentRecords.create_enrollment_record(%{
          user_id: student.user_id,
          group_id: enrolled_status.id,
          group_type: "status",
          academic_year: "2026-2027",
          start_date: ~D[2026-04-01],
          is_current: true
        })

      assert {:ok, updated_student} =
               ArchiveService.process_archive(student, ~D[2026-07-01], "2026-2027")

      assert updated_student.status == "archived"
      assert Users.get_student!(student.id).status == "archived"

      previous = Repo.get!(EnrollmentRecord, current_enrollment.id)
      refute previous.is_current
      assert previous.end_date == ~D[2026-07-01]

      archived_enrollment =
        Repo.one!(
          from(e in EnrollmentRecord,
            where:
              e.user_id == ^student.user_id and e.group_type == "status" and
                e.group_id == ^archived_status.id
          )
        )

      assert archived_enrollment.is_current
      assert archived_enrollment.start_date == ~D[2026-07-01]
      assert archived_enrollment.academic_year == "2026-2027"
    end

    test "leaves another student's enrollments and status untouched" do
      {_user, student} = student_fixture()
      {_other_user, other_student} = student_fixture()
      enrolled_status = status_fixture(%{title: :enrolled})
      archived_status()

      {:ok, other_enrollment} =
        EnrollmentRecords.create_enrollment_record(%{
          user_id: other_student.user_id,
          group_id: enrolled_status.id,
          group_type: "status",
          academic_year: "2026-2027",
          start_date: ~D[2026-04-01],
          is_current: true
        })

      assert {:ok, _student} =
               ArchiveService.process_archive(student, ~D[2026-07-01], "2026-2027")

      assert Repo.get!(EnrollmentRecord, other_enrollment.id) == other_enrollment
      assert Users.get_student!(other_student.id).status == other_student.status
    end

    test "refuses a student who is already archived" do
      {_user, student} = student_fixture()
      archived_status()

      assert {:ok, _student} =
               ArchiveService.process_archive(student, ~D[2026-07-01], "2026-2027")

      student = Users.get_student!(student.id)

      assert {:error, "Student is already marked as archived"} =
               ArchiveService.process_archive(student, ~D[2026-08-01], "2026-2027")
    end

    test "archives a student who was previously marked as a dropout" do
      {_user, student} = student_fixture()
      archived_status()

      {:ok, student} = Users.update_student(student, %{"status" => "dropout"})

      assert {:ok, updated_student} =
               ArchiveService.process_archive(student, ~D[2026-07-01], "2026-2027")

      assert updated_student.status == "archived"
    end

    test "fails and changes nothing when the archived status is not configured" do
      {_user, student} = student_fixture()
      remove_archived_status()

      assert {:error, "Archived status not found in the system"} =
               ArchiveService.process_archive(student, ~D[2026-07-01], "2026-2027")

      assert Users.get_student!(student.id).status == student.status
    end
  end

  # `archived` is inserted by migration 20261105120000, so every environment —
  # including the test database — already has exactly one of it.
  defp archived_status do
    Repo.one!(from(s in Status, where: s.title == :archived))
  end

  defp remove_archived_status do
    status = archived_status()
    Repo.delete_all(from(g in Group, where: g.type == "status" and g.child_id == ^status.id))
    Repo.delete!(status)
  end
end
