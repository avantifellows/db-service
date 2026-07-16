defmodule Dbservice.Services.StudentEligibilityCleanupTest do
  use Dbservice.DataCase, async: false

  import Ecto.Query

  alias Dbservice.Services.StudentUpdateService
  alias Dbservice.Services.GroupUpdateService
  alias Dbservice.Services.DropoutService

  test "a dropout transition ends the Student's active Holistic Mapping" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()

    assert {:ok, updated_student} =
             StudentUpdateService.update_student_with_user_data(student, %{"status" => "dropout"})

    assert updated_student.status == "dropout"

    assert Repo.query!(
             """
             SELECT ended_at IS NOT NULL, end_source, end_reason
             FROM holistic_mentorship_mentor_mentee_mappings
             WHERE id = $1
             """,
             [mapping_id]
           ).rows == [[true, "db_service_student_eligibility", "student_dropout"]]

    assert Repo.query!("SELECT count(*) FROM holistic_mentorship_mentor_mentee_mappings").rows ==
             [
               [1]
             ]
  end

  test "a canonical Grade change ends the Student's active Holistic Mapping" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()
    old_grade_id = insert_grade(11)
    new_grade_id = insert_grade(12)

    Repo.query!("UPDATE student SET grade_id = $1 WHERE id = $2", [old_grade_id, student.id])
    student = Dbservice.Users.get_student!(student.id)

    assert {:ok, updated_student} =
             StudentUpdateService.update_student_with_user_data(student, %{
               "grade_id" => new_grade_id
             })

    assert updated_student.grade_id == new_grade_id

    assert Repo.query!(
             """
             SELECT ended_at IS NOT NULL, end_source, end_reason
             FROM holistic_mentorship_mentor_mentee_mappings
             WHERE id = $1
             """,
             [mapping_id]
           ).rows == [[true, "db_service_student_eligibility", "student_grade_changed"]]
  end

  test "a cleanup failure rolls back the Grade correction and its enrollment changes" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()
    old_grade_id = insert_grade(9)
    new_grade_id = insert_grade(10)
    {:ok, old_group} = Dbservice.Groups.create_group(%{type: "grade", child_id: old_grade_id})
    {:ok, new_group} = Dbservice.Groups.create_group(%{type: "grade", child_id: new_grade_id})

    Repo.query!("UPDATE student SET grade_id = $1 WHERE id = $2", [old_grade_id, student.id])

    {:ok, group_user} =
      Dbservice.GroupUsers.create_group_user(%{user_id: student.user_id, group_id: old_group.id})

    {:ok, enrollment} =
      Dbservice.EnrollmentRecords.create_enrollment_record(%{
        user_id: student.user_id,
        group_id: old_grade_id,
        group_type: "grade",
        academic_year: "2026-27",
        start_date: ~D[2026-04-01],
        is_current: true
      })

    install_failing_cleanup_trigger()

    assert_raise Postgrex.Error, fn ->
      GroupUpdateService.update_user_group_by_type(%{
        "user_id" => student.user_id,
        "group_id" => new_group.id,
        "type" => "grade"
      })
    end

    assert Repo.get!(Dbservice.Groups.GroupUser, group_user.id).group_id == old_group.id

    assert Repo.get!(Dbservice.EnrollmentRecords.EnrollmentRecord, enrollment.id).group_id ==
             old_grade_id

    assert Dbservice.Users.get_student!(student.id).grade_id == old_grade_id
    assert mapping_active?(mapping_id)
  end

  test "a cleanup failure rolls back the dropout status and enrollment changes" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()
    {:ok, enrolled_status} = Dbservice.Statuses.create_status(%{"title" => "enrolled"})
    {:ok, dropout_status} = Dbservice.Statuses.create_status(%{"title" => "dropout"})

    {:ok, current_enrollment} =
      Dbservice.EnrollmentRecords.create_enrollment_record(%{
        user_id: student.user_id,
        group_id: enrolled_status.id,
        group_type: "status",
        academic_year: "2026-27",
        start_date: ~D[2026-04-01],
        is_current: true
      })

    install_failing_cleanup_trigger()

    assert_raise Postgrex.Error, fn ->
      DropoutService.process_dropout(student, ~D[2026-07-01], "2026-27")
    end

    assert Repo.get!(Dbservice.EnrollmentRecords.EnrollmentRecord, current_enrollment.id).is_current
    assert Dbservice.Users.get_student!(student.id).status == "enrolled"
    assert mapping_active?(mapping_id)

    refute Repo.exists?(
             from enrollment in Dbservice.EnrollmentRecords.EnrollmentRecord,
               where:
                 enrollment.user_id == ^student.user_id and
                   enrollment.group_id == ^dropout_status.id and
                   enrollment.group_type == "status"
           )
  end

  test "dropout takes precedence when status and Grade change together" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()
    new_grade_id = insert_grade(12)

    assert {:ok, _updated_student} =
             StudentUpdateService.update_student_with_user_data(student, %{
               "status" => "dropout",
               "grade_id" => new_grade_id
             })

    assert Repo.query!(
             "SELECT end_reason FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
             [mapping_id]
           ).rows == [["student_dropout"]]
  end

  test "unchanged eligibility leaves the active Mapping unchanged" do
    %{mapping_id: mapping_id, student: student} = insert_mapping_scope()

    assert {:ok, _updated_student} =
             StudentUpdateService.update_student_with_user_data(student, %{
               "status" => "enrolled",
               "father_name" => "Updated"
             })

    assert Repo.query!(
             "SELECT ended_at, end_source, end_reason FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
             [mapping_id]
           ).rows == [[nil, nil, nil]]
  end

  defp insert_mapping_scope do
    [[student_user_id], [mentor_user_id]] =
      Repo.query!(
        "INSERT INTO \"user\" (inserted_at, updated_at) VALUES (now(), now()), (now(), now()) RETURNING id"
      ).rows

    [[student_id]] =
      Repo.query!(
        "INSERT INTO student (user_id, status, inserted_at, updated_at) VALUES ($1, 'enrolled', now(), now()) RETURNING id",
        [student_user_id]
      ).rows

    [[school_id]] =
      Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('Eligibility Cleanup', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('Eligibility Cleanup', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[mapping_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_mentor_mentee_mappings
          (student_id, mentor_user_id, school_id, program_id, academic_year, started_at,
           assignment_source)
        VALUES ($1, $2, $3, $4, '2026-27', timezone('UTC', now()), 'af_lms')
        RETURNING id
        """,
        [student_id, mentor_user_id, school_id, program_id]
      ).rows

    %{mapping_id: mapping_id, student: Dbservice.Users.get_student!(student_id)}
  end

  defp insert_grade(number) do
    [[id]] =
      Repo.query!(
        "INSERT INTO grade (number, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [number]
      ).rows

    id
  end

  defp install_failing_cleanup_trigger do
    Repo.query!("""
    CREATE FUNCTION pg_temp.fail_holistic_mapping_cleanup() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'forced cleanup failure';
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER fail_holistic_mapping_cleanup
    BEFORE UPDATE ON holistic_mentorship_mentor_mentee_mappings
    FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_holistic_mapping_cleanup()
    """)
  end

  defp mapping_active?(mapping_id) do
    Repo.query!(
      "SELECT ended_at IS NULL FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
      [mapping_id]
    ).rows == [[true]]
  end
end
