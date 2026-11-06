defmodule Dbservice.Services.StudentIdentifierCorrectionServiceTest do
  use Dbservice.DataCase, async: false

  import Dbservice.AuthGroupsFixtures
  import Dbservice.UsersFixtures

  alias Dbservice.EnrollmentRecords
  alias Dbservice.Services.StudentIdentifierCorrectionService, as: Correction
  alias Dbservice.Users

  describe "process_correction/2" do
    test "corrects a student_id" do
      {_user, student} = student_fixture(%{student_id: "SIC-WRONG"})

      assert {:ok, updated} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-RIGHT"})

      assert updated.student_id == "SIC-RIGHT"
      assert Users.get_student!(student.id).student_id == "SIC-RIGHT"
    end

    test "corrects an apaar_id, and both at once" do
      {_user, student} = student_fixture(%{student_id: "SIC-BOTH", apaar_id: "555555555565"})

      assert {:ok, updated} =
               Correction.process_correction(student, %{
                 "new_student_id" => "SIC-BOTH-FIXED",
                 "new_apaar_id" => "555555555566"
               })

      assert updated.student_id == "SIC-BOTH-FIXED"
      assert updated.apaar_id == "555555555566"
    end

    test "leaves the other identifier alone when only one is given" do
      {_user, student} = student_fixture(%{student_id: "SIC-KEEP", apaar_id: "555555555567"})

      assert {:ok, updated} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-KEEP-FIXED"})

      assert updated.apaar_id == "555555555567"
    end

    test "fails a row that corrects nothing" do
      {_user, student} = student_fixture(%{student_id: "SIC-EMPTY"})

      assert {:error, message} =
               Correction.process_correction(student, %{"new_student_id" => "  "})

      assert message =~ "must carry new_student_id or new_apaar_id"
    end

    test "refuses an apaar_id another student already holds" do
      {_user, student} = student_fixture(%{student_id: "SIC-AP"})

      {_other_user, other} =
        student_fixture(%{student_id: "SIC-AP-OWNER", apaar_id: "555555555568"})

      assert {:error, message} =
               Correction.process_correction(student, %{"new_apaar_id" => "555555555568"})

      assert message =~ "already exists for another student"
      assert Users.get_student!(student.id).apaar_id == student.apaar_id
      assert Users.get_student!(other.id).apaar_id == "555555555568"
    end

    test "refuses a student_id another student in the same auth group holds" do
      auth_group = auth_group_fixture(%{name: "SIC_GROUP"})
      {_user, student} = student_fixture(%{student_id: "SIC-IN-GROUP"})
      {_other_user, other} = student_fixture(%{student_id: "SIC-TAKEN"})

      for user_id <- [student.user_id, other.user_id] do
        {:ok, _er} =
          EnrollmentRecords.create_enrollment_record(%{
            "user_id" => user_id,
            "group_id" => auth_group.id,
            "group_type" => "auth_group",
            "start_date" => ~D[2026-04-01],
            "is_current" => true
          })
      end

      assert {:error, message} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-TAKEN"})

      assert message =~ "already belongs to another student"
      assert Users.get_student!(student.id).student_id == "SIC-IN-GROUP"
    end

    test "allows a student_id held by a student in a different auth group" do
      # 476 student_ids in production legitimately match two students in different
      # auth groups, so this must not be treated as a conflict.
      group_a = auth_group_fixture(%{name: "SIC_GROUP_A"})
      group_b = auth_group_fixture(%{name: "SIC_GROUP_B"})
      {_user, student} = student_fixture(%{student_id: "SIC-CROSS"})
      {_other_user, _other} = student_fixture(%{student_id: "SIC-SHARED"})

      {:ok, _er} =
        EnrollmentRecords.create_enrollment_record(%{
          "user_id" => student.user_id,
          "group_id" => group_a.id,
          "group_type" => "auth_group",
          "start_date" => ~D[2026-04-01],
          "is_current" => true
        })

      {:ok, _er} =
        EnrollmentRecords.create_enrollment_record(%{
          "user_id" => Users.get_student_by_student_id("SIC-SHARED").user_id,
          "group_id" => group_b.id,
          "group_type" => "auth_group",
          "start_date" => ~D[2026-04-01],
          "is_current" => true
        })

      assert {:ok, updated} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-SHARED"})

      assert updated.student_id == "SIC-SHARED"
    end

    test "refuses a student_id held anywhere when the student has no auth group" do
      # Nothing to scope the uniqueness by, so an unverifiable duplicate is refused
      # rather than written.
      {_user, student} = student_fixture(%{student_id: "SIC-NO-GROUP"})
      {_other_user, _other} = student_fixture(%{student_id: "SIC-ELSEWHERE"})

      assert {:error, message} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-ELSEWHERE"})

      assert message =~ "already belongs to another student"
    end

    test "re-applying the same value is a no-op, not a conflict" do
      {_user, student} = student_fixture(%{student_id: "SIC-SAME"})

      assert {:ok, updated} =
               Correction.process_correction(student, %{"new_student_id" => "SIC-SAME"})

      assert updated.student_id == "SIC-SAME"
    end
  end
end
