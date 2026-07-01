defmodule DbserviceWeb.LmsStudentUpdateControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group
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
      {_user, student} = insert_enrolled_student!(school, grade, batch)
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
                 "student_dropout",
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
      assert affected_identifiers["student_id"] == student.student_id
      assert affected_identifiers["apaar_id"] == student.apaar_id
      assert changed_values["status"] == %{"old" => student.status, "new" => "dropout"}
      assert changed_values["dropout_date"] == %{"old" => nil, "new" => "2026-07-01"}
      assert changed_values["academic_year"] == %{"old" => nil, "new" => "2026-2027"}
    end
  end

  describe "PATCH /api/lms/students/:student_id/update-with-enrollments" do
    test "updates safe profile fields and audits old and new values", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
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
      assert updated_user.gender == "Others"
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
      assert changed_values["first_name"] == %{"old" => user.first_name, "new" => "Updated Name"}
      assert changed_values["last_name"] == %{"old" => user.last_name, "new" => ""}
      assert changed_values["category"] == %{"old" => "Gen", "new" => "OBC"}
    end

    test "rejects locked identity fields without changing editable fields", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")
      {user, student} = insert_enrolled_student!(school, grade, batch)

      conn =
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "first_name" => "Should Not Apply",
          "student_id" => "SHOULD-NOT-CHANGE"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "locked_fields"
      assert response["error"]["fields"] == ["student_id"]
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
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
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
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "g10_board" => "CENTRAL BOARD OF SECONDARY EDUCATION"
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "invalid_g10_roll_for_board"
      assert Repo.get!(Student, student.id).g10_board == "RAJASTHAN BOARD OF SECONDARY EDUCATION"
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
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
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
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

    test "stream edits atomically update stream and derived batch", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      new_batch = insert_nvs_batch!(11, "medical")
      {_user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
          "actor" => actor(),
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "stream" => "medical"
        })

      response = json_response(conn, 200)
      assert response["changed_fields"] == ["batch_id", "stream"]
      assert Repo.get!(Student, student.id).stream == "medical"
      assert current_enrollment(student.user_id, "grade").group_id == grade.id
      assert current_enrollment(student.user_id, "batch").group_id == new_batch.id

      refute Repo.get_by(EnrollmentRecord,
               user_id: student.user_id,
               group_type: "batch",
               group_id: old_batch.id
             ).is_current
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
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
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

    test "rejects stream edits when batch lookup is not exactly one match", %{conn: conn} do
      school = insert_school!()
      grade = insert_grade!(11)
      old_batch = insert_nvs_batch!(11, "engineering")
      {_user, student} = insert_enrolled_student!(school, grade, old_batch)

      conn =
        patch(conn, "/api/lms/students/#{student.id}/update-with-enrollments", %{
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
        patch(recycle(conn), "/api/lms/students/#{student.id}/update-with-enrollments", %{
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

  defp insert_school! do
    school =
      Repo.insert!(%School{
        code: "JNV001",
        name: "JNV Test",
        udise_code: "12345678901",
        af_school_category: "JNV",
        district_code: "D001",
        district: "Hyderabad",
        state_code: "TS",
        state: "Telangana",
        program_ids: [64]
      })

    Repo.insert!(%Group{type: "school", child_id: school.id})
    school
  end

  defp insert_grade!(number) do
    grade = Repo.get_by(Grade, number: number) || Repo.insert!(%Grade{number: number})
    ensure_group!("grade", grade.id)
    grade
  end

  defp insert_nvs_batch!(grade, stream) do
    product = Dbservice.ProductsFixtures.product_fixture(%{code: "NVS"})

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

  defp only_audit_changed_values do
    [[changed_values]] =
      Ecto.Adapters.SQL.query!(Repo, "SELECT changed_values FROM lms_student_write_audits").rows

    changed_values
  end
end
