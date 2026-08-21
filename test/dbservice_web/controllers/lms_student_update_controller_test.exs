defmodule DbserviceWeb.LmsStudentUpdateControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group
  alias Dbservice.LmsStudentRegistrationMode
  alias Dbservice.Repo
  alias Dbservice.Schools.School
  alias Dbservice.Statuses.Status
  alias Dbservice.Users
  alias Dbservice.Users.Student

  describe "PATCH /api/dropout" do
    test "marks the student dropout and writes LMS audit metadata", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{pen_number: "12345678901"})

      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM centres")
      dropout_status = ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      response = json_response(conn, 200)
      assert response["status"] == "dropout"
      assert Repo.get!(Student, student.id).status == "dropout"
      assert current_enrollment(student.user_id, "status").group_id == dropout_status.id

      assert [
               [
                 "student_program_dropout",
                 501,
                 "pm@example.org",
                 "google",
                 "program_manager",
                 school_code,
                 school_udise_code,
                 64,
                 affected_identifiers,
                 changed_values
               ]
             ] =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 "SELECT action, actor_user_id, actor_email, actor_login_type, actor_role, school_code, school_udise_code, program_id, affected_identifiers, changed_values FROM lms_student_write_audits"
               ).rows

      assert school_code == school.code
      assert school_udise_code == school.udise_code
      assert affected_identifiers["student_pk_id"] == student.id
      assert affected_identifiers["user_id"] == user.id
      assert affected_identifiers["student_id"] == student.student_id
      assert affected_identifiers["pen_number"] == "12345678901"
      assert affected_identifiers["apaar_id"] == student.apaar_id
      assert changed_values["status"] == %{"old" => student.status, "new" => "dropout"}
      assert changed_values["batch_id"] == %{"old" => batch.id, "new" => nil}
      assert changed_values["batch_enrollment_is_current"] == %{"old" => true, "new" => false}

      assert changed_values["batch_enrollment_end_date"] == %{
               "old" => nil,
               "new" => "2026-07-01"
             }

      assert changed_values["dropout_date"] == %{"old" => nil, "new" => "2026-07-01"}
      assert changed_values["academic_year"] == %{"old" => nil, "new" => "2026-2027"}
    end

    test "finds a PEN-only student for dropout", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {_user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: nil,
          pen_number: "12345678901"
        })

      ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "pen_number" => student.pen_number,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 200)["status"] == "dropout"
    end

    test "rejects dropout identifiers that belong to different students", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {_first_user, first_student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "202812345678",
          pen_number: "12345678901",
          apaar_id: "123456789012"
        })

      {_second_user, second_student} =
        Dbservice.UsersFixtures.student_fixture(%{
          student_id: "202812345679",
          pen_number: "12345678902",
          apaar_id: "123456789013",
          grade_id: grade.id
        })

      insert_enrollment!(second_student.user_id, school.id, "school")
      insert_enrollment!(second_student.user_id, grade.id, "grade")
      insert_enrollment!(second_student.user_id, batch.id, "batch")

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => first_student.student_id,
          "pen_number" => second_student.pen_number,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Conflicting student identifiers"
      assert Repo.get!(Student, first_student.id).status == first_student.status
      assert Repo.get!(Student, second_student.id).status == second_student.status
    end

    test "drops only the selected program when another program remains active", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      nvs_batch = insert_nvs_batch!(11, "engineering")
      coe_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, nvs_batch)
      insert_enrollment!(user.id, coe_batch.id, "batch")
      ensure_group_user!(user.id, "batch", coe_batch.id)

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 200)["status"] == student.status
      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment(user.id, 1).group_id == coe_batch.id
      assert current_enrollment(user.id, "grade").group_id == grade.id
      assert current_enrollment(user.id, "school").group_id == school.id
      refute current_program_enrollment_or_nil(user.id, 64)
      refute has_group_user?(user.id, "batch", nvs_batch.id)
      assert has_group_user?(user.id, "batch", coe_batch.id)
      assert has_group_user?(user.id, "grade", grade.id)
      assert has_group_user?(user.id, "school", school.id)

      ended_enrollment = Repo.get_by!(EnrollmentRecord, user_id: user.id, group_id: nvs_batch.id)
      refute ended_enrollment.is_current
      assert ended_enrollment.end_date == ~D[2026-07-01]

      [[action, program_id, changed_values]] =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT action, program_id, changed_values FROM lms_student_write_audits"
        ).rows

      assert action == "student_program_dropout"
      assert program_id == 64
      assert changed_values["status"] == %{"old" => student.status, "new" => student.status}
    end

    test "rejects audited dropout for the wrong school without changing status", %{conn: conn} do
      school = insert_school!()
      other_school = insert_school!(%{code: "JNV002", udise_code: "22345678901"})
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => other_school.code, "udise_code" => other_school.udise_code},
          "program_id" => 64
        })

      response = json_response(conn, 400)
      assert response["errors"] == "Student is not enrolled in this school"
      assert Repo.get!(Student, student.id).status == student.status
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "drops a selected non-NVS program without changing NVS enrollment", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      nvs_batch = insert_nvs_batch!(11, "engineering")
      other_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, nvs_batch)
      insert_enrollment!(user.id, other_batch.id, "batch")
      ensure_group_user!(user.id, "batch", other_batch.id)

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 1
        })

      assert json_response(conn, 200)["status"] == student.status
      refute current_program_enrollment_or_nil(user.id, 1)
      assert current_program_enrollment(user.id, 64).group_id == nvs_batch.id
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 1
    end

    test "rejects dropout for an inactive NVS program without changing enrollments", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      program = Repo.get!(Dbservice.Programs.Program, 64)
      Repo.update!(Ecto.Changeset.change(program, is_current: false))

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Program must be a current NVS program"
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert has_group_user?(user.id, "batch", batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects malformed dropout audit metadata without changing status", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => school.code,
          "program_id" => 64
        })

      response = json_response(conn, 400)
      assert response["errors"] == "Invalid LMS audit metadata"
      assert Repo.get!(Student, student.id).status == student.status
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "does not allow a program-scoped dropout without actor and school metadata", %{
      conn: conn
    } do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Invalid LMS audit metadata"
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert Repo.get!(Student, student.id).status == student.status
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "audit persistence failure rolls back the NVS dropout with a safe error", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => Map.put(actor(), "user_id", "invalid"),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Failed to write dropout audit"
      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert has_group_user?(user.id, "batch", batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "missing actor metadata rolls back the NVS dropout", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => Map.put(actor(), "email", nil),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Failed to write dropout audit"
      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert has_group_user?(user.id, "batch", batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "missing batch membership rolls back the NVS enrollment change", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      from(gu in Dbservice.Groups.GroupUser,
        join: g in Group,
        on: g.id == gu.group_id,
        where: gu.user_id == ^user.id and g.type == "batch" and g.child_id == ^batch.id
      )
      |> Repo.delete_all()

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] == "Failed to end program enrollment"
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects a student without a current batch in the selected NVS program", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      nvs_batch = insert_nvs_batch!(11, "engineering")
      other_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, other_batch)

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] ==
               "Student is not currently enrolled in this program"

      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment(user.id, 1).group_id == other_batch.id
      assert has_group_user?(user.id, "batch", other_batch.id)
      refute current_program_enrollment_or_nil(user.id, 64)
      refute has_group_user?(user.id, "batch", nvs_batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects multiple current batches in the selected program without changing enrollments",
         %{
           conn: conn
         } do
      school = insert_school!()
      grade = insert_grade!(11)
      first_batch = insert_nvs_batch!(11, "engineering")
      second_batch = insert_nvs_batch!(11, "medical")
      {user, student} = insert_enrolled_student!(school, grade, first_batch)
      insert_enrollment!(user.id, second_batch.id, "batch")

      conn =
        patch(conn, "/api/dropout", %{
          "student_id" => student.student_id,
          "start_date" => "2026-07-01",
          "academic_year" => "2026-2027",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })

      assert json_response(conn, 400)["errors"] ==
               "Student has multiple current batches in this program"

      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment_count(user.id, 64) == 2
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "undoes the exact NVS dropout while leaving another program active", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      nvs_batch = insert_nvs_batch!(11, "engineering")
      coe_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, nvs_batch)
      insert_enrollment!(user.id, coe_batch.id, "batch")
      ensure_group_user!(user.id, "batch", coe_batch.id)

      patch(conn, "/api/dropout", %{
        "student_id" => student.student_id,
        "start_date" => "2026-07-01",
        "academic_year" => "2026-2027",
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      response =
        patch(conn, "/api/lms/students/undo-program-dropout", %{
          "student_id" => student.student_id,
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })
        |> json_response(200)

      assert response["status"] == student.status
      assert current_program_enrollment(user.id, 64).group_id == nvs_batch.id
      assert current_program_enrollment(user.id, 1).group_id == coe_batch.id
      assert has_group_user?(user.id, "batch", nvs_batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 2
    end

    test "undo restores globally ended enrollment records for a final-program dropout", %{
      conn: conn
    } do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      patch(conn, "/api/dropout", %{
        "student_id" => student.student_id,
        "start_date" => "2026-07-01",
        "academic_year" => "2026-2027",
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      patch(conn, "/api/lms/students/undo-program-dropout", %{
        "student_id" => student.student_id,
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      assert Repo.get!(Student, student.id).status == student.status
      assert current_program_enrollment(user.id, 64).group_id == batch.id
      assert current_enrollment(user.id, "school").group_id == school.id
      assert current_enrollment(user.id, "grade").group_id == grade.id

      refute Repo.exists?(
               from(e in EnrollmentRecord,
                 where:
                   e.user_id == ^user.id and e.group_type == "status" and e.is_current == true
               )
             )
    end

    test "blocks a second undo and an undo when another NVS batch is active", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "medical")
      coe_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, old_batch)
      insert_enrollment!(user.id, coe_batch.id, "batch")
      ensure_group_user!(user.id, "batch", coe_batch.id)

      patch(conn, "/api/dropout", %{
        "student_id" => student.student_id,
        "start_date" => "2026-07-01",
        "academic_year" => "2026-2027",
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      insert_enrollment!(user.id, new_batch.id, "batch")

      blocked =
        patch(conn, "/api/lms/students/undo-program-dropout", %{
          "student_id" => student.student_id,
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })
        |> json_response(400)

      assert blocked["errors"] == "Student already has an active NVS batch"
      Repo.delete!(current_program_enrollment(user.id, 64))

      patch(conn, "/api/lms/students/undo-program-dropout", %{
        "student_id" => student.student_id,
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      second =
        patch(conn, "/api/lms/students/undo-program-dropout", %{
          "student_id" => student.student_id,
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })
        |> json_response(400)

      assert second["errors"] == "This dropout cannot be undone"
    end

    test "blocks undo when the previous NVS batch is closed", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)
      ensure_dropout_status!()

      patch(conn, "/api/dropout", %{
        "student_id" => student.student_id,
        "start_date" => "2026-07-01",
        "academic_year" => "2026-2027",
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64
      })
      |> json_response(200)

      batch
      |> Ecto.Changeset.change(end_date: Date.add(Date.utc_today(), -1))
      |> Repo.update!()

      response =
        patch(conn, "/api/lms/students/undo-program-dropout", %{
          "student_id" => student.student_id,
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64
        })
        |> json_response(400)

      assert response["errors"] == "The previous NVS batch is closed"
    end
  end

  describe "PATCH /api/lms/students/:student_id/update-with-enrollments" do
    test "preserves a phone-cohort Student ID on a phone-mode grade edit", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      response = json_response(conn, 200)

      assert response["changed_fields"] == ["batch_id", "g12_graduating_year", "grade"]
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Users.get_user!(user.id).phone == "9456591269"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id
      refute Map.has_key?(only_audit_changed_values(), "student_id")

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "grade",
               group_id: grade11.id
             ).is_current

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "preserves a phone-cohort Student ID on an approved-mode grade edit", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade"
             ]

      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Users.get_user!(user.id).phone == "9456591269"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id
      refute Map.has_key?(only_audit_changed_values(), "student_id")

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "grade",
               group_id: grade11.id
             ).is_current

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "preserves a phone-cohort Student ID on a phone-mode stream edit", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "nda")

      {user, student} =
        insert_enrolled_student!(school, grade, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => " NDA "
        })

      assert json_response(conn, 200)["changed_fields"] == ["batch_id", "stream"]
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Repo.get!(Student, student.id).stream == "nda"
      assert Users.get_user!(user.id).phone == "9456591269"
      assert current_enrollment(user.id, "batch").group_id == new_batch.id
      refute Map.has_key?(only_audit_changed_values(), "student_id")

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "corrects a phone-cohort phone and Student ID together in phone mode", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => " 9876543210 "
        })

      assert json_response(conn, 200)["changed_fields"] == ["phone", "student_id"]
      assert Users.get_user!(user.id).phone == "9876543210"
      assert Repo.get!(Student, student.id).student_id == "9876543210"
      assert current_enrollment(user.id, "school").group_id == school.id
      assert current_enrollment(user.id, "batch").group_id == batch.id
      assert current_enrollment(user.id, "auth_group").group_id == enable_students.id
      assert has_group_user?(user.id, "school", school.id)
      assert has_group_user?(user.id, "batch", batch.id)
      assert has_group_user?(user.id, "auth_group", enable_students.id)

      assert only_audit_changed_values() == %{
               "phone" => %{"old" => "9456591269", "new" => "9876543210"},
               "student_id" => %{"old" => "9456591269", "new" => "9876543210"}
             }
    end

    test "keeps the phone-based Student ID during a combined phone and grade correction", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => "9876543216",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "phone",
               "student_id"
             ]

      updated_user = Users.get_user!(user.id)
      updated_student = Repo.get!(Student, student.id)
      assert updated_user.phone == "9876543216"
      assert updated_student.grade_id == grade12.id
      assert updated_student.g12_graduating_year == 2027
      assert updated_student.student_id == "9876543216"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id
      assert current_enrollment(user.id, "school").group_id == school.id
      assert current_enrollment(user.id, "auth_group").group_id == enable_students.id
      assert has_group_user?(user.id, "auth_group", enable_students.id)
      refute has_group_user?(user.id, "batch", old_batch.id)

      changed_values = only_audit_changed_values()
      assert changed_values["phone"] == %{"old" => "9456591269", "new" => "9876543216"}

      assert changed_values["student_id"] == %{
               "old" => "9456591269",
               "new" => "9876543216"
             }
    end

    test "rejects a phone correction that belongs to another EnableStudents Student", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      other_school = insert_school!(%{code: "JNV002", udise_code: "22345678901"})
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      {other_user, other_student} =
        insert_enrolled_student!(other_school, grade, batch, %{
          student_id: "9876543211",
          apaar_id: "123456789013",
          g10_roll_no: nil
        })

      Repo.update!(Ecto.Changeset.change(other_user, phone: "9876543211"))
      enable_students = insert_auth_group!("EnableStudents")

      for enrolled_user <- [user, other_user] do
        ensure_group_user!(enrolled_user.id, "auth_group", enable_students.id)
        insert_enrollment!(enrolled_user.id, enable_students.id, "auth_group")
      end

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => "9876543211"
        })

      response = json_response(conn, 409)
      assert response["error"]["code"] == "phone_student_id_conflict"
      assert response["error"]["fields"] == ["phone"]
      assert is_binary(response["error"]["message"])

      assert response["error"]["existing_match"] == %{
               "school_code" => other_school.code,
               "school_name" => other_school.name,
               "udise_code" => other_school.udise_code,
               "district" => other_school.district,
               "state" => other_school.state,
               "grade" => 11,
               "program" => "JNV NVS",
               "stream" => "engineering"
             }

      refute Map.has_key?(response["error"]["existing_match"], "student_pk_id")
      refute Map.has_key?(response["error"]["existing_match"], "user_id")
      refute Map.has_key?(response["error"]["existing_match"], "student_id")
      refute Map.has_key?(response["error"]["existing_match"], "phone")

      assert Users.get_user!(user.id).phone == "9456591269"
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Users.get_user!(other_user.id).phone == "9876543211"
      assert Repo.get!(Student, other_student.id).student_id == "9876543211"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects a cohort phone correction outside the 6-9 rule without writes", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => " 5123456789 "
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "invalid_phone"
      assert response["error"]["fields"] == ["phone"]
      assert Users.get_user!(user.id).phone == "9456591269"
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "corrects a phone-cohort phone and Student ID in approved mode", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => " 9876543213 "
        })

      assert json_response(conn, 200)["changed_fields"] == ["phone", "student_id"]
      assert Users.get_user!(user.id).phone == "9876543213"
      assert Repo.get!(Student, student.id).student_id == "9876543213"

      assert only_audit_changed_values() == %{
               "phone" => %{"old" => "9456591269", "new" => "9876543213"},
               "student_id" => %{"old" => "9456591269", "new" => "9876543213"}
             }
    end

    test "allows a correction when the new phone belongs only to another auth group", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      other_school = insert_school!(%{code: "JNV002", udise_code: "22345678901"})
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      {other_user, other_student} =
        insert_enrolled_student!(other_school, grade, batch, %{
          student_id: "9876543214",
          apaar_id: "123456789013",
          g10_roll_no: nil
        })

      Repo.update!(Ecto.Changeset.change(other_user, phone: "9876543214"))
      enable_students = insert_auth_group!("EnableStudents")
      other_auth_group = insert_auth_group!("OtherStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")
      ensure_group_user!(other_user.id, "auth_group", other_auth_group.id)
      insert_enrollment!(other_user.id, other_auth_group.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => "9876543214"
        })

      assert json_response(conn, 200)["changed_fields"] == ["phone", "student_id"]
      assert Users.get_user!(user.id).phone == "9876543214"
      assert Repo.get!(Student, student.id).student_id == "9876543214"
      assert Users.get_user!(other_user.id).phone == "9876543214"
      assert Repo.get!(Student, other_student.id).student_id == "9876543214"
    end

    test "rolls back both phone identities when the correction audit fails", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("phone")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "registration_mode" => "phone",
          "actor" => Map.put(actor(), "user_id", "invalid"),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => "9876543215"
        })

      assert json_response(conn, 422)["error"]["code"] == "audit_update_failed"
      assert Users.get_user!(user.id).phone == "9456591269"
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "keeps legacy Student ID re-derivation without current EnableStudents membership", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "student_id"
             ]

      assert Repo.get!(Student, student.id).student_id == nil
      assert Users.get_user!(user.id).phone == "9456591269"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id

      assert only_audit_changed_values()["student_id"] == %{
               "old" => "9456591269",
               "new" => nil
             }

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "grade",
               group_id: grade11.id
             ).is_current

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "keeps generic program edits free of an NVS Program 64 guard", %{conn: conn} do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_program_batch!(7, 11, "engineering")
      new_batch = insert_program_batch!(7, 12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 7,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "student_id"
             ]

      assert Repo.get!(Student, student.id).student_id == nil
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_program_enrollment(user.id, 7).group_id == new_batch.id

      assert only_audit_changed_values()["student_id"] == %{
               "old" => "9456591269",
               "new" => nil
             }

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "does not classify a student without current enrollment at the resolved School", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "9456591269",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      from(e in EnrollmentRecord,
        where: e.user_id == ^user.id and e.group_type == "school" and e.group_id == ^school.id
      )
      |> Repo.update_all(set: [is_current: false])

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 403)["error"]["code"] == "school_mismatch"
      assert Repo.get!(Student, student.id).student_id == "9456591269"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "keeps legacy Student ID re-derivation when Student ID differs from user phone", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "different-student-id",
          g10_roll_no: nil
        })

      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "student_id"
             ]

      assert Repo.get!(Student, student.id).student_id == nil
      assert Users.get_user!(user.id).phone == "9456591269"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id

      assert only_audit_changed_values()["student_id"] == %{
               "old" => "different-student-id",
               "new" => nil
             }

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "keeps legacy Student ID re-derivation when the phone fails phone-mode validation", %{
      conn: conn
    } do
      :ok = LmsStudentRegistrationMode.put_test_active_mode("approved")
      on_exit(fn -> LmsStudentRegistrationMode.put_test_active_mode(nil) end)

      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade11, old_batch, %{
          student_id: "1234567890",
          g10_roll_no: nil
        })

      user = Repo.update!(Ecto.Changeset.change(user, phone: "1234567890"))
      enable_students = insert_auth_group!("EnableStudents")
      ensure_group_user!(user.id, "auth_group", enable_students.id)
      insert_enrollment!(user.id, enable_students.id, "auth_group")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "student_id"
             ]

      assert Repo.get!(Student, student.id).student_id == nil
      assert Users.get_user!(user.id).phone == "1234567890"
      assert current_enrollment(user.id, "grade").group_id == grade12.id
      assert current_enrollment(user.id, "batch").group_id == new_batch.id

      assert only_audit_changed_values()["student_id"] == %{
               "old" => "1234567890",
               "new" => nil
             }

      refute Repo.get_by(EnrollmentRecord,
               user_id: user.id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "rejects a registration-mode mismatch before looking up the student", %{conn: conn} do
      before_students = Repo.aggregate(Student, :count, :id)
      before_audits = Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id)

      response =
        conn
        |> patch("/api/lms/students/999999/update-with-enrollments", %{
          "registration_mode" => "phone",
          "registration_mode_version" => "1",
          "school" => %{"code" => "missing", "udise_code" => "invalid"}
        })
        |> json_response(409)

      assert response["error"]["code"] == "registration_mode_mismatch"
      assert is_binary(response["error"]["message"])
      assert Map.keys(response) == ["error"]
      assert Enum.sort(Map.keys(response["error"])) == ["code", "message"]
      assert Repo.aggregate(Student, :count, :id) == before_students
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == before_audits
    end

    test "rejects missing and non-string registration handshake values before any write", %{
      conn: conn
    } do
      before_users = Repo.aggregate(Dbservice.Users.User, :count, :id)
      before_students = Repo.aggregate(Student, :count, :id)
      before_audits = Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id)

      malformed_handshakes = [
        %{"registration_mode_version" => "1"},
        %{"registration_mode" => "approved"},
        %{"registration_mode" => "future", "registration_mode_version" => "1"},
        %{"registration_mode" => "approved", "registration_mode_version" => "2"},
        %{"registration_mode" => 123, "registration_mode_version" => "1"},
        %{"registration_mode" => "approved", "registration_mode_version" => 1}
      ]

      Enum.each(malformed_handshakes, fn handshake ->
        response =
          conn
          |> recycle()
          |> patch(
            "/api/lms/students/999999/update-with-enrollments",
            Map.merge(handshake, %{
              "school" => %{"code" => "missing", "udise_code" => "invalid"}
            })
          )
          |> json_response(409)

        assert response["error"]["code"] == "registration_mode_mismatch"
        assert is_binary(response["error"]["message"])
        assert Enum.sort(Map.keys(response["error"])) == ["code", "message"]
        refute Map.has_key?(response, "results")
      end)

      assert Repo.aggregate(Dbservice.Users.User, :count, :id) == before_users
      assert Repo.aggregate(Student, :count, :id) == before_students
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == before_audits
    end

    test "updates an NVS student without a Centre or school program_ids", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{pen_number: "12345678901"})

      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM centres")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Updated Name"
        })

      assert json_response(conn, 200)["status"] == "updated"
      assert Users.get_user!(user.id).first_name == "Updated Name"
    end

    test "updates a student regardless of which program they are enrolled in", %{conn: conn} do
      # The update guard is program-agnostic: it only checks that the student is
      # currently enrolled in the supplied program at the supplied school. Any
      # program id works — program eligibility policy belongs in the LMS layer,
      # not here. Uses an arbitrary program id to make that independence explicit.
      arbitrary_program_id = 7
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_program_batch!(arbitrary_program_id, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => arbitrary_program_id,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Updated Name"
        })

      assert json_response(conn, 200)["status"] == "updated"
      assert Users.get_user!(user.id).first_name == "Updated Name"
    end

    test "rejects a school outside the student's current enrollment", %{conn: conn} do
      school = insert_school!()
      other_school = insert_school!(%{code: "JNV002", udise_code: "22345678901"})
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{
            "code" => other_school.code,
            "udise_code" => other_school.udise_code
          },
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply"
        })

      assert json_response(conn, 403)["error"]["code"] == "school_mismatch"
      assert Users.get_user!(user.id).first_name == user.first_name
    end

    test "updates safe profile fields and audits old and new values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{pen_number: "12345678901"})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Updated Name",
          "last_name" => "",
          "gender" => "Others",
          "category" => "OBC"
        })

      response = json_response(conn, 200)
      assert response["status"] == "updated"
      assert response["student_pk_id"] == student.id
      assert response["changed_fields"] == ["category", "first_name", "gender", "last_name"]

      updated_user = Users.get_user!(user.id)
      updated_student = Repo.get!(Student, student.id)
      assert updated_user.first_name == "Updated Name"
      assert updated_user.last_name == nil
      assert updated_user.gender == "Other"
      assert updated_student.category == "OBC"
      assert updated_student.student_id == "202812345678"

      assert [
               [
                 "student_update",
                 "pm@example.org",
                 school_code,
                 64,
                 affected_identifiers,
                 changed_values
               ]
             ] =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 "SELECT action, actor_email, school_code, program_id, affected_identifiers, changed_values FROM lms_student_write_audits"
               ).rows

      assert school_code == school.code
      assert affected_identifiers["student_pk_id"] == student.id
      assert affected_identifiers["user_id"] == user.id
      assert affected_identifiers["student_id"] == student.student_id
      assert affected_identifiers["pen_number"] == "12345678901"
      assert affected_identifiers["apaar_id"] == student.apaar_id
      assert changed_values["first_name"] == %{"old" => user.first_name, "new" => "Updated Name"}
      assert changed_values["last_name"] == %{"old" => user.last_name, "new" => nil}
      assert changed_values["gender"] == %{"old" => user.gender, "new" => "Other"}
      assert changed_values["category"] == %{"old" => "Gen", "new" => "OBC"}
    end

    test "profile-only edits do not rederive identity or enrollments", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{student_id: "LEGACY-ID"})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "phone" => "9999999999"
        })

      assert json_response(conn, 200)["changed_fields"] == ["phone"]
      assert Repo.get!(Student, student.id).student_id == "LEGACY-ID"
      assert current_enrollment(student.user_id, "grade").group_id == grade.id
      assert current_program_enrollment(student.user_id, 64).group_id == batch.id
      assert Users.get_user!(user.id).phone == "9999999999"
    end

    test "rejects a student without a current NVS enrollment", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      from(e in EnrollmentRecord,
        where: e.user_id == ^user.id and e.group_type == "batch",
        update: [set: [is_current: false]]
      )
      |> Repo.update_all([])

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply"
        })

      assert json_response(conn, 403)["error"]["code"] == "program_mismatch"
      assert Users.get_user!(user.id).first_name != "Should Not Apply"
    end

    test "allows a profile-only edit even with multiple current batches", %{conn: conn} do
      # "One batch per program per student" is a business invariant owned by the
      # LMS, not the schema — so the update service must not block a harmless
      # profile-only edit just because the student has more than one current
      # batch in the program. (A grade/stream reassignment is a separate case,
      # covered below.)
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      extra_batch = insert_nvs_batch!(11, "medical")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      insert_enrollment!(user.id, extra_batch.id, "batch")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Applied"
        })

      assert json_response(conn, 200)["status"] == "updated"
      assert Users.get_user!(user.id).first_name == "Applied"
    end

    test "rejects a grade/stream reassignment when multiple current batches are ambiguous",
         %{conn: conn} do
      # The single-batch requirement still applies where it is actually needed:
      # resolving which current batch to move the student off during a
      # grade/stream change.
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      extra_batch = insert_nvs_batch!(11, "medical")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      insert_enrollment!(user.id, extra_batch.id, "batch")

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "medical"
        })

      assert json_response(conn, 409)["error"]["code"] == "multiple_current_batches"
      assert Users.get_user!(user.id).first_name == user.first_name
    end

    test "returns 422 for invalid editable enum values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "gender" => "Unknown"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "invalid_user_fields"

      conn =
        lms_update(recycle(conn), student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "category" => "General"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "invalid_category_pair"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects invalid stream values without clearing the stored stream", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "Unknown"
        })

      assert json_response(conn, 422)["error"]["code"] == "invalid_stream"
      assert Repo.get!(Student, student.id).stream == "engineering"
      assert current_program_enrollment(student.user_id, 64).group_id == batch.id
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects null canonical enum inputs", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      metadata = %{
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64,
        "academic_year" => "2026-2027",
        "start_date" => "2026-07-01"
      }

      for field <- ~w(g10_board gender stream) do
        conn =
          lms_update(
            recycle(conn),
            student.id,
            Map.put(metadata, field, nil)
          )

        assert json_response(conn, 422)["error"]["code"] == "invalid_#{field}"
      end

      assert Repo.get!(Student, student.id).stream == "engineering"
      assert Repo.get!(Student, student.id).g10_board == "CENTRAL BOARD OF SECONDARY EDUCATION"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects a category that does not match the resulting CWSN status", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {_user, student} =
        insert_enrolled_student!(school, grade, batch, %{physically_handicapped: false})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "category" => "PWD-OBC"
        })

      assert json_response(conn, 422)["error"]["code"] == "invalid_category_pair"
      assert Repo.get!(Student, student.id).category == "Gen"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects invalid phone and DOB values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      metadata = %{
        "actor" => actor(),
        "school" => %{"code" => school.code, "udise_code" => school.udise_code},
        "program_id" => 64,
        "academic_year" => "2026-2027",
        "start_date" => "2026-07-01"
      }

      conn =
        lms_update(
          conn,
          student.id,
          Map.put(metadata, "phone", "0123456789")
        )

      assert json_response(conn, 422)["error"]["code"] == "invalid_phone"

      conn =
        lms_update(
          recycle(conn),
          student.id,
          Map.put(metadata, "date_of_birth", "2016-01-01")
        )

      assert json_response(conn, 422)["error"]["code"] == "invalid_date_of_birth"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "normalizes day-first DOB edits", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "date_of_birth" => "31/12/2010"
        })

      assert json_response(conn, 200)["changed_fields"] == ["date_of_birth"]
      assert Users.get_user!(user.id).date_of_birth == ~D[2010-12-31]
    end

    test "rejects every locked identity field even when PEN is currently null", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply",
          "student_id" => "SHOULD-NOT-CHANGE",
          "pen_number" => "12345678901",
          "g10_roll_no" => "87654321",
          "apaar_id" => "987654321098"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "locked_fields"

      assert response["error"]["fields"] == [
               "apaar_id",
               "g10_roll_no",
               "pen_number",
               "student_id"
             ]

      assert Users.get_user!(user.id).first_name == user.first_name
      assert Repo.get!(Student, student.id).student_id == "202812345678"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects fields outside the PRD editable contract", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "mother_name" => "Not In Contract"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "unsupported_fields"
      assert response["error"]["fields"] == ["mother_name"]
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects G10 board edits when the locked G10 roll is invalid for the new board", %{
      conn: conn
    } do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {_user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          g10_board: "RAJASTHAN BOARD OF SECONDARY EDUCATION",
          g10_roll_no: "ABC123"
        })

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "CBSE"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "invalid_g10_roll_for_board"
      assert Repo.get!(Student, student.id).g10_board == "RAJASTHAN BOARD OF SECONDARY EDUCATION"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "stores canonical Others board as null", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "Others"
        })

      assert json_response(conn, 200)["changed_fields"] == ["g10_board"]
      assert Repo.get!(Student, student.id).g10_board == nil

      assert only_audit_changed_values()["g10_board"] == %{
               "old" => "CENTRAL BOARD OF SECONDARY EDUCATION",
               "new" => nil
             }
    end

    test "trims G10 board before validating an edit", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => " CBSE "
        })

      assert json_response(conn, 200)["changed_fields"] == ["g10_board"]
      assert Repo.get!(Student, student.id).g10_board == "CBSE"
    end

    test "rejects Others board when the locked roll is not already canonical", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {_user, student} =
        insert_enrolled_student!(school, grade, batch, %{
          g10_board: "CBSE",
          g10_roll_no: "01234567"
        })

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "Others"
        })

      assert json_response(conn, 422)["error"]["code"] == "invalid_g10_roll_for_board"
      assert Repo.get!(Student, student.id).g10_board == "CBSE"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "stores canonical CBSE, CWSN category, and Other gender values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, student} =
        insert_enrolled_student!(school, grade, batch, %{physically_handicapped: false})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "CBSE",
          "physically_handicapped" => true,
          "category" => "PWD-OBC",
          "gender" => "Other"
        })

      assert json_response(conn, 200)["changed_fields"] == [
               "category",
               "g10_board",
               "gender",
               "physically_handicapped"
             ]

      updated_student = Repo.get!(Student, student.id)
      assert updated_student.g10_board == "CBSE"
      assert updated_student.physically_handicapped
      assert updated_student.category == "PWD-OBC"
      assert Users.get_user!(user.id).gender == "Other"
    end

    test "rejects a board outside the canonical edit values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "ICSE"
        })

      assert json_response(conn, 422)["error"]["code"] == "invalid_g10_board"
      assert Repo.get!(Student, student.id).g10_board == "CENTRAL BOARD OF SECONDARY EDUCATION"
    end

    test "grade edits atomically update derived identity, grade enrollment, and batch", %{
      conn: conn
    } do
      school = insert_school!()
      grade11 = insert_grade!(11)
      grade12 = insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(12, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade11, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "grade" => 12
        })

      response = json_response(conn, 200)

      assert response["changed_fields"] == [
               "batch_id",
               "g12_graduating_year",
               "grade",
               "student_id"
             ]

      updated_student = Repo.get!(Student, student.id)
      assert updated_student.grade_id == grade12.id
      assert updated_student.g12_graduating_year == 2027
      assert updated_student.student_id == "202712345678"

      assert current_enrollment(student.user_id, "grade").group_id == grade12.id
      assert current_enrollment(student.user_id, "batch").group_id == new_batch.id

      refute Repo.get_by(EnrollmentRecord,
               user_id: student.user_id,
               group_type: "grade",
               group_id: grade11.id
             ).is_current

      refute Repo.get_by(EnrollmentRecord,
               user_id: student.user_id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current

      changed_values = only_audit_changed_values()
      assert changed_values["grade"] == %{"old" => 11, "new" => 12}
      assert changed_values["student_id"] == %{"old" => "202812345678", "new" => "202712345678"}
      assert changed_values["batch_id"] == %{"old" => old_batch.id, "new" => new_batch.id}
    end

    test "NDA stream edits atomically update stream and derived batch", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "nda")
      {_user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => " NDA "
        })

      response = json_response(conn, 200)
      assert response["changed_fields"] == ["batch_id", "stream"]
      assert Repo.get!(Student, student.id).stream == "nda"
      assert Repo.get!(Student, student.id).student_id == student.student_id
      assert current_enrollment(student.user_id, "grade").group_id == grade.id
      assert current_enrollment(student.user_id, "batch").group_id == new_batch.id

      refute Repo.get_by(EnrollmentRecord,
               user_id: student.user_id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
    end

    test "stream edits leave another program's current batch untouched", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "medical")
      coe_batch = insert_program_batch!(1, 11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, old_batch)
      insert_enrollment!(user.id, coe_batch.id, "batch")
      ensure_group_user!(user.id, "batch", coe_batch.id)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "medical"
        })

      assert json_response(conn, 200)["changed_fields"] == ["batch_id", "stream"]
      assert current_program_enrollment(user.id, 64).group_id == new_batch.id
      assert current_program_enrollment(user.id, 1).group_id == coe_batch.id
      refute has_group_user?(user.id, "batch", old_batch.id)
      assert has_group_user?(user.id, "batch", new_batch.id)
      assert has_group_user?(user.id, "batch", coe_batch.id)
    end

    test "grade edits derive graduating year from academic year", %{conn: conn} do
      school = insert_school!()
      grade11 = insert_grade!(11)
      insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      insert_nvs_batch!(12, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade11, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2027-2028",
          "start_date" => "2027-07-01",
          "grade" => 12
        })

      assert json_response(conn, 200)["status"] == "updated"
      updated_student = Repo.get!(Student, student.id)
      assert updated_student.g12_graduating_year == 2028
      assert updated_student.student_id == "202812345678"
    end

    test "stream-only edit preserves legacy Student ID when G10 roll is absent", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "medical")

      {_user, student} =
        insert_enrolled_student!(school, grade, old_batch, %{
          student_id: "LEGACY-ID",
          g10_roll_no: nil
        })

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "medical"
        })

      response = json_response(conn, 200)
      assert response["changed_fields"] == ["batch_id", "stream"]
      assert Repo.get!(Student, student.id).student_id == "LEGACY-ID"
      assert current_enrollment(student.user_id, "batch").group_id == new_batch.id
    end

    test "blank last name does not create a false changed field when already nil", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)
      {:ok, _user} = Users.update_user(user, %{last_name: nil})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "last_name" => ""
        })

      response = json_response(conn, 200)
      assert response["changed_fields"] == []
      assert only_audit_changed_values() == %{}
    end

    test "duplicate generated Student ID on grade edit leaves profile and enrollments unchanged",
         %{
           conn: conn
         } do
      school = insert_school!()
      grade11 = insert_grade!(11)
      insert_grade!(12)
      old_batch = insert_nvs_batch!(11, "engineering")
      insert_nvs_batch!(12, "engineering")
      {user, student} = insert_enrolled_student!(school, grade11, old_batch)
      Dbservice.UsersFixtures.student_fixture(%{student_id: "202712345678"})

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply",
          "grade" => 12
        })

      response = json_response(conn, 409)
      assert response["error"]["code"] == "duplicate_student_id"
      assert Users.get_user!(user.id).first_name == user.first_name
      assert Repo.get!(Student, student.id).student_id == "202812345678"
      assert current_enrollment(student.user_id, "grade").group_id == grade11.id
      assert current_enrollment(student.user_id, "batch").group_id == old_batch.id
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "audit validation failure rolls back profile and NVS enrollment changes", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      insert_nvs_batch!(11, "medical")
      {user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => Map.put(actor(), "user_id", "invalid"),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply",
          "stream" => "medical"
        })

      assert json_response(conn, 422)["error"]["code"] == "audit_update_failed"
      assert Users.get_user!(user.id).first_name == user.first_name
      assert Repo.get!(Student, student.id).stream == "engineering"
      assert current_program_enrollment(user.id, 64).group_id == old_batch.id
      assert has_group_user?(user.id, "batch", old_batch.id)
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "missing actor metadata rolls back the update", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        lms_update(conn, student.id, %{
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply"
        })

      assert json_response(conn, 422)["error"]["code"] == "audit_update_failed"
      assert Users.get_user!(user.id).first_name == user.first_name
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "rejects stream edits when batch lookup is not exactly one match", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "clat"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "batch_not_found"
      assert Repo.get!(Student, student.id).stream == "engineering"
      assert current_enrollment(student.user_id, "batch").group_id == old_batch.id

      insert_nvs_batch!(11, "medical")
      insert_nvs_batch!(11, "medical")

      conn =
        lms_update(recycle(conn), student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "medical"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "multiple_batches"
      assert Repo.get!(Student, student.id).stream == "engineering"
      assert current_enrollment(student.user_id, "batch").group_id == old_batch.id
    end

    test "rejects a target batch without a batch group and rolls back profile changes", %{
      conn: conn
    } do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      target_batch = insert_nvs_batch!(11, "nda")
      Repo.delete!(Repo.get_by!(Group, type: "batch", child_id: target_batch.id))
      {user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        lms_update(conn, student.id, %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply",
          "stream" => "nda"
        })

      assert json_response(conn, 422)["error"]["code"] == "batch_group_not_found"
      assert Users.get_user!(user.id).first_name == user.first_name
      assert Repo.get!(Student, student.id).stream == "engineering"
      assert current_program_enrollment(user.id, 64).group_id == old_batch.id
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end
  end

  defp lms_update(conn, student_id, params) do
    patch(
      conn,
      "/api/lms/students/#{student_id}/update-with-enrollments",
      Map.merge(
        %{
          "registration_mode" => "approved",
          "registration_mode_version" => "1"
        },
        params
      )
    )
  end

  defp actor do
    %{
      "user_id" => 501,
      "email" => "pm@example.org",
      "login_type" => "google",
      "role" => "program_manager"
    }
  end

  defp insert_enrolled_student!(school, grade, batch, attrs \\ %{}) do
    insert_active_centre!(school, batch.program_id)

    {user, student} =
      %{
        student_id: "202812345678",
        apaar_id: "123456789012",
        g10_board: "CENTRAL BOARD OF SECONDARY EDUCATION",
        g10_roll_no: "12345678",
        category: "Gen",
        stream: "engineering",
        grade_id: grade.id,
        g12_graduating_year: 2028
      }
      |> Map.merge(attrs)
      |> Dbservice.UsersFixtures.student_fixture()

    insert_enrollment!(user.id, school.id, "school")
    insert_enrollment!(user.id, grade.id, "grade")
    insert_enrollment!(user.id, batch.id, "batch")
    ensure_group_user!(user.id, "school", school.id)
    ensure_group_user!(user.id, "grade", grade.id)
    ensure_group_user!(user.id, "batch", batch.id)
    {user, student}
  end

  defp insert_auth_group!(name) do
    auth_group = Repo.insert!(%Dbservice.Groups.AuthGroup{name: name})
    ensure_group!("auth_group", auth_group.id)
    auth_group
  end

  defp insert_active_centre!(school, program_id) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "INSERT INTO centres (name, school_id, program_id, is_active) VALUES ($1, $2, $3, true)",
      ["#{school.name} Centre", school.id, program_id]
    )
  end

  defp insert_school!(attrs \\ %{}) do
    school =
      %{
        code: "JNV001",
        name: "JNV Test",
        udise_code: "12345678901",
        af_school_category: "JNV",
        district_code: "D001",
        district: "Hyderabad",
        state_code: "TS",
        state: "Telangana",
        program_ids: []
      }
      |> Map.merge(attrs)
      |> then(&struct(School, &1))
      |> Repo.insert!()

    Repo.insert!(%Group{type: "school", child_id: school.id})
    school
  end

  defp insert_grade!(number) do
    grade = Repo.get_by(Grade, number: number) || Repo.insert!(%Grade{number: number})
    ensure_group!("grade", grade.id)
    grade
  end

  defp insert_nvs_batch!(grade, stream) do
    product = Dbservice.ProductsFixtures.product_fixture(%{code: "TP-Async"})

    Repo.get(Dbservice.Programs.Program, 64) ||
      Repo.insert!(%Dbservice.Programs.Program{
        id: 64,
        name: "JNV NVS",
        product_id: product.id,
        target_outreach: 100,
        donor: "NVS",
        state: "India",
        model: "Lakshya",
        is_current: true
      })

    {:ok, batch} =
      Dbservice.Batches.create_batch_from_import(%{
        "name" => "NVS #{grade} #{stream}",
        "batch_id" => "EnableStudents_TP_#{if grade == 11, do: 2028, else: 2027}_#{stream}",
        "program_id" => 64,
        "metadata" => %{"grade" => grade, "stream" => stream}
      })

    ensure_group!("batch", batch.id)
    batch
  end

  defp insert_program_batch!(program_id, grade, stream) do
    product = Dbservice.ProductsFixtures.product_fixture(%{code: "PROGRAM-#{program_id}"})

    Repo.get(Dbservice.Programs.Program, program_id) ||
      Repo.insert!(%Dbservice.Programs.Program{
        id: program_id,
        name: "Program #{program_id}",
        product_id: product.id,
        target_outreach: 100,
        donor: "Test",
        state: "India",
        model: "Test",
        is_current: true
      })

    {:ok, batch} =
      Dbservice.Batches.create_batch_from_import(%{
        "name" => "Program #{program_id} #{grade} #{stream}",
        "batch_id" => "PROGRAM_#{program_id}_#{grade}_#{stream}",
        "program_id" => program_id,
        "metadata" => %{"grade" => grade, "stream" => stream}
      })

    ensure_group!("batch", batch.id)
    batch
  end

  defp insert_enrollment!(user_id, group_id, group_type) do
    Repo.insert!(%EnrollmentRecord{
      user_id: user_id,
      group_id: group_id,
      group_type: group_type,
      academic_year: "2026-2027",
      start_date: ~D[2026-06-01],
      is_current: true
    })
  end

  defp ensure_group_user!(user_id, type, child_id) do
    group = ensure_group!(type, child_id)
    Repo.insert!(%Dbservice.Groups.GroupUser{user_id: user_id, group_id: group.id})
  end

  defp ensure_group!(type, child_id) do
    Repo.get_by(Group, type: type, child_id: child_id) ||
      Repo.insert!(%Group{type: type, child_id: child_id})
  end

  defp ensure_dropout_status! do
    status =
      Repo.get_by(Status, title: :dropout) ||
        Repo.insert!(%Status{title: :dropout})

    ensure_group!("status", status.id)
    status
  end

  defp current_enrollment(user_id, group_type) do
    Repo.one!(
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true
      )
    )
  end

  defp current_program_enrollment(user_id, program_id) do
    Repo.one!(
      from(e in EnrollmentRecord,
        join: b in Dbservice.Batches.Batch,
        on: b.id == e.group_id,
        where:
          e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
            b.program_id == ^program_id
      )
    )
  end

  defp current_program_enrollment_or_nil(user_id, program_id) do
    Repo.one(
      from(e in EnrollmentRecord,
        join: b in Dbservice.Batches.Batch,
        on: b.id == e.group_id,
        where:
          e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
            b.program_id == ^program_id
      )
    )
  end

  defp current_program_enrollment_count(user_id, program_id) do
    Repo.aggregate(
      from(e in EnrollmentRecord,
        join: b in Dbservice.Batches.Batch,
        on: b.id == e.group_id,
        where:
          e.user_id == ^user_id and e.group_type == "batch" and e.is_current == true and
            b.program_id == ^program_id
      ),
      :count,
      :id
    )
  end

  defp has_group_user?(user_id, type, child_id) do
    Repo.exists?(
      from(gu in Dbservice.Groups.GroupUser,
        join: g in Group,
        on: g.id == gu.group_id,
        where: gu.user_id == ^user_id and g.type == ^type and g.child_id == ^child_id
      )
    )
  end

  defp only_audit_changed_values do
    [[changed_values]] =
      Ecto.Adapters.SQL.query!(Repo, "SELECT changed_values FROM lms_student_write_audits").rows

    changed_values
  end
end
