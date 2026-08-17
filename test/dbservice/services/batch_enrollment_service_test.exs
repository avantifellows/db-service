defmodule Dbservice.Services.BatchEnrollmentServiceTest do
  use Dbservice.DataCase

  alias Dbservice.Services.BatchEnrollmentService
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  import Dbservice.BatchesFixtures
  import Dbservice.StatusesFixtures
  import Dbservice.UsersFixtures
  import Dbservice.EnrollmentRecordFixtures
  import Dbservice.GradesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.ProgramsFixtures

  describe "get_batch_info/1" do
    test "returns batch info when batch exists" do
      batch = batch_fixture()

      result = BatchEnrollmentService.get_batch_info(batch.batch_id)

      assert result != nil
      {_group_id, child_id, group_type} = result
      assert child_id == batch.id
      assert group_type == "batch"
    end

    test "returns nil when batch does not exist" do
      result = BatchEnrollmentService.get_batch_info("non-existent-batch-id")

      assert is_nil(result)
    end
  end

  describe "get_enrolled_status_info/0" do
    test "returns enrolled status info when enrolled status exists" do
      # Clean up any existing enrolled statuses first
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      # Create an enrolled status
      status = status_fixture(%{title: "enrolled"})

      result = BatchEnrollmentService.get_enrolled_status_info()

      assert result != nil
      {status_id, group_type} = result
      assert status_id == status.id
      assert group_type == "status"
    end

    test "returns nil when enrolled status does not exist" do
      # Ensure no enrolled status exists
      from(s in Dbservice.Statuses.Status, where: s.title == :enrolled)
      |> Dbservice.Repo.delete_all()

      result = BatchEnrollmentService.get_enrolled_status_info()

      assert is_nil(result)
    end
  end

  describe "existing_batch_enrollment?/2" do
    test "returns true when user is currently enrolled in batch" do
      user = user_fixture()
      batch = batch_fixture()

      # Create a current enrollment record
      enrollment_record_fixture(%{
        user_id: user.id,
        group_id: batch.id,
        group_type: "batch",
        is_current: true
      })

      result = BatchEnrollmentService.existing_batch_enrollment?(user.id, batch.id)

      assert result == true
    end

    test "returns false when user is not enrolled in batch" do
      user = user_fixture()
      batch = batch_fixture()

      result = BatchEnrollmentService.existing_batch_enrollment?(user.id, batch.id)

      assert result == false
    end

    test "returns false when user has non-current enrollment in batch" do
      user = user_fixture()
      batch = batch_fixture()

      # Create a non-current enrollment record
      enrollment_record_fixture(%{
        user_id: user.id,
        group_id: batch.id,
        group_type: "batch",
        is_current: false
      })

      result = BatchEnrollmentService.existing_batch_enrollment?(user.id, batch.id)

      assert result == false
    end

    test "returns false when user is enrolled in different batch" do
      user = user_fixture()
      batch1 = batch_fixture()
      batch2 = batch_fixture()

      # Create enrollment in batch1
      enrollment_record_fixture(%{
        user_id: user.id,
        group_id: batch1.id,
        group_type: "batch",
        is_current: true
      })

      # Check for batch2
      result = BatchEnrollmentService.existing_batch_enrollment?(user.id, batch2.id)

      assert result == false
    end
  end

  describe "get_grade_info/1" do
    test "returns grade info when grade exists" do
      grade = grade_fixture(%{number: 10})

      result = BatchEnrollmentService.get_grade_info(10)

      assert result != nil
      {_group_id, child_id, group_type} = result
      assert child_id == grade.id
      assert group_type == "grade"
    end

    test "returns nil when grade does not exist" do
      result = BatchEnrollmentService.get_grade_info(999)

      assert is_nil(result)
    end
  end

  describe "grade_changed?/2" do
    test "returns true when grade has changed" do
      user = user_fixture()
      grade1 = grade_fixture(%{number: 9})
      grade2 = grade_fixture(%{number: 10})

      # Create enrollment record with grade1
      enrollment_record_fixture(%{
        user_id: user.id,
        group_id: grade1.id,
        group_type: "grade",
        is_current: true
      })

      result = BatchEnrollmentService.grade_changed?(user.id, grade2.id)

      assert result == true
    end

    test "returns false when grade has not changed" do
      user = user_fixture()
      grade = grade_fixture(%{number: 10})

      # Create enrollment record with the same grade
      enrollment_record_fixture(%{
        user_id: user.id,
        group_id: grade.id,
        group_type: "grade",
        is_current: true
      })

      result = BatchEnrollmentService.grade_changed?(user.id, grade.id)

      assert result == false
    end

    test "returns true when user has no current grade enrollment" do
      user = user_fixture()
      grade = grade_fixture(%{number: 10})

      result = BatchEnrollmentService.grade_changed?(user.id, grade.id)

      assert result == true
    end
  end

  describe "update_student_grade/2" do
    test "successfully updates student grade" do
      {_user, student} = student_fixture()
      grade = grade_fixture(%{number: 10})

      result = BatchEnrollmentService.update_student_grade(student, grade.id)

      assert {:ok, updated_student} = result
      assert updated_student.grade_id == grade.id
    end
  end

  describe "update_batch_user/2" do
    test "updates existing batch group user when one exists" do
      user = user_fixture()
      batch = batch_fixture()

      # Get the group that was automatically created for the batch
      batch_group = Dbservice.Groups.get_group_by_child_id_and_type(batch.id, "batch")

      # Create existing batch group user
      {:ok, existing_group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: batch_group.id
        })

      # Create a new batch
      new_batch = batch_fixture()
      new_batch_group = Dbservice.Groups.get_group_by_child_id_and_type(new_batch.id, "batch")

      result = BatchEnrollmentService.update_batch_user(user.id, new_batch_group.id)

      assert {:ok, updated_group_user} = result
      assert updated_group_user.id == existing_group_user.id
      assert updated_group_user.group_id == new_batch_group.id
      assert updated_group_user.user_id == user.id
    end

    test "creates new batch group user when none exists" do
      user = user_fixture()
      batch = batch_fixture()

      # Get the group that was automatically created for the batch
      group = Dbservice.Groups.get_group_by_child_id_and_type(batch.id, "batch")

      result = BatchEnrollmentService.update_batch_user(user.id, group.id)

      assert {:ok, new_group_user} = result
      assert new_group_user.group_id == group.id
      assert new_group_user.user_id == user.id
    end

    test "collapses duplicate batch group users to the target, deleting the stale ones" do
      user = user_fixture()
      old_batch = batch_fixture()
      stale_batch = batch_fixture()
      new_batch = batch_fixture()

      old_group = Dbservice.Groups.get_group_by_child_id_and_type(old_batch.id, "batch")
      stale_group = Dbservice.Groups.get_group_by_child_id_and_type(stale_batch.id, "batch")
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_batch.id, "batch")

      {:ok, _} =
        Dbservice.GroupUsers.create_group_user(%{user_id: user.id, group_id: old_group.id})

      {:ok, _} =
        Dbservice.GroupUsers.create_group_user(%{user_id: user.id, group_id: stale_group.id})

      result = BatchEnrollmentService.update_batch_user(user.id, new_group.id)

      assert {:ok, kept} = result
      assert kept.group_id == new_group.id

      remaining =
        Dbservice.Repo.all(
          from(gu in Dbservice.Groups.GroupUser,
            join: g in Dbservice.Groups.Group,
            on: g.id == gu.group_id and g.type == "batch",
            where: gu.user_id == ^user.id,
            select: gu.group_id
          )
        )

      assert remaining == [new_group.id]
    end

    test "creates new batch group user when existing group user is not of batch type" do
      user = user_fixture()
      batch = batch_fixture()

      # Get the group that was automatically created for the batch
      group = Dbservice.Groups.get_group_by_child_id_and_type(batch.id, "batch")

      # Create existing group user of different type (school)
      school = school_fixture()
      school_group = Dbservice.Groups.get_group_by_child_id_and_type(school.id, "school")

      {:ok, existing_group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: school_group.id
        })

      result = BatchEnrollmentService.update_batch_user(user.id, group.id)

      assert {:ok, new_group_user} = result
      assert new_group_user.group_id == group.id
      assert new_group_user.user_id == user.id
      # Should be a different record than the existing one
      assert new_group_user.id != existing_group_user.id
    end
  end

  describe "update_grade_user/2" do
    test "updates existing grade group user when one exists" do
      user = user_fixture()
      grade = grade_fixture()

      # Get the group that was automatically created for the grade
      group = Dbservice.Groups.get_group_by_child_id_and_type(grade.id, "grade")

      # Create existing grade group user
      {:ok, existing_group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: group.id
        })

      # Create a new grade
      new_grade = grade_fixture()
      new_group = Dbservice.Groups.get_group_by_child_id_and_type(new_grade.id, "grade")

      result = BatchEnrollmentService.update_grade_user(user.id, new_group.id)

      assert {:ok, updated_group_user} = result
      assert updated_group_user.id == existing_group_user.id
      assert updated_group_user.group_id == new_group.id
      assert updated_group_user.user_id == user.id
    end

    test "creates new grade group user when none exists" do
      user = user_fixture()
      grade = grade_fixture()

      # Get the group that was automatically created for the grade
      group = Dbservice.Groups.get_group_by_child_id_and_type(grade.id, "grade")

      result = BatchEnrollmentService.update_grade_user(user.id, group.id)

      assert {:ok, new_group_user} = result
      assert new_group_user.group_id == group.id
      assert new_group_user.user_id == user.id
    end

    test "creates new grade group user when existing group user is not of grade type" do
      user = user_fixture()
      grade = grade_fixture()

      # Get the group that was automatically created for the grade
      group = Dbservice.Groups.get_group_by_child_id_and_type(grade.id, "grade")

      # Create existing group user of different type (school)
      school = school_fixture()
      school_group = Dbservice.Groups.get_group_by_child_id_and_type(school.id, "school")

      {:ok, existing_group_user} =
        Dbservice.GroupUsers.create_group_user(%{
          user_id: user.id,
          group_id: school_group.id
        })

      result = BatchEnrollmentService.update_grade_user(user.id, group.id)

      assert {:ok, new_group_user} = result
      assert new_group_user.group_id == group.id
      assert new_group_user.user_id == user.id
      # Should be a different record than the existing one
      assert new_group_user.id != existing_group_user.id
    end
  end

  describe "handle_batch_enrollment/5 program-scoped ER inactivation (issue #656)" do
    test "moving batch within one program leaves other programs' current batch ER intact" do
      user = user_fixture()
      program_a = program_fixture()
      program_b = program_fixture()

      batch_a1 = batch_fixture(%{program_id: program_a.id, batch_id: "A1"})
      batch_a2 = batch_fixture(%{program_id: program_a.id, batch_id: "A2"})
      batch_b1 = batch_fixture(%{program_id: program_b.id, batch_id: "B1"})

      # Student currently has one current batch enrollment in each program.
      # enrollment_record.group_id for a batch is the batch id.
      current_batch_er(user.id, batch_a1.id)
      current_batch_er(user.id, batch_b1.id)

      # Move within program A: enroll into batch_a2.
      BatchEnrollmentService.handle_batch_enrollment(
        user.id,
        batch_a2.id,
        "batch",
        "2024-2025",
        ~D[2024-02-01]
      )

      # Program A: old batch ER ended, new batch ER current.
      refute batch_er_current?(user.id, batch_a1.id)
      assert batch_er_current?(user.id, batch_a2.id)
      # Program B: its batch ER is untouched (the bug this fixes ended it too).
      assert batch_er_current?(user.id, batch_b1.id)
    end
  end

  describe "exclusive-current unique index (issue #656)" do
    test "a second current exclusive enrollment returns a changeset error, not a raise" do
      user = user_fixture()

      {:ok, _} =
        EnrollmentRecords.create_enrollment_record(%{
          "user_id" => user.id,
          "group_id" => 1,
          "group_type" => "auth_group",
          "start_date" => ~D[2024-01-01],
          "is_current" => true
        })

      assert {:error, %Ecto.Changeset{} = changeset} =
               EnrollmentRecords.create_enrollment_record(%{
                 "user_id" => user.id,
                 "group_id" => 2,
                 "group_type" => "auth_group",
                 "start_date" => ~D[2024-01-01],
                 "is_current" => true
               })

      refute changeset.valid?
      assert changeset.errors != []
    end

    test "batch is not covered by the exclusive constraint (multi-program allowed)" do
      user = user_fixture()

      {:ok, _} =
        EnrollmentRecords.create_enrollment_record(%{
          user_id: user.id,
          group_id: 1,
          group_type: "batch",
          academic_year: "2024-2025",
          start_date: ~D[2024-01-01],
          is_current: true
        })

      assert {:ok, %EnrollmentRecord{}} =
               EnrollmentRecords.create_enrollment_record(%{
                 user_id: user.id,
                 group_id: 2,
                 group_type: "batch",
                 academic_year: "2024-2025",
                 start_date: ~D[2024-01-01],
                 is_current: true
               })
    end
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
end
