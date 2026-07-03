defmodule DbserviceWeb.LmsStudentIngestionControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  alias Dbservice.AuthGroups
  alias Dbservice.Batches.Batch
  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Repo
  alias Dbservice.Schools.School
  alias Dbservice.Users
  alias Dbservice.Users.User
  alias Dbservice.Users.Student

  describe "POST /api/lms/students/bulk-create-with-enrollments" do
    test "creates one NVS student with derived identity, enrollments, and audit", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      conn =
        post(conn, "/api/lms/students/bulk-create-with-enrollments", %{
          "actor" => %{
            "user_id" => 501,
            "email" => "pm@example.org",
            "login_type" => "google",
            "role" => "program_manager"
          },
          "school" => %{"code" => school.code, "udise_code" => school.udise_code},
          "program_id" => 64,
          "upload" => %{"id" => "upload-1", "filename" => "students.xlsx"},
          "academic_year" => "2026-2027",
          "start_date" => "2026-07-01",
          "rows" => [
            %{
              "row_number" => 2,
              "grade" => 11,
              "student_name" => "Asha Kumar",
              "date_of_birth" => "2010-01-02",
              "gender" => "Female",
              "category" => "Gen",
              "physically_handicapped" => false,
              "apaar_id" => "123456789012",
              "g10_board" => "CENTRAL BOARD OF SECONDARY EDUCATION",
              "g10_roll_no" => "1234 5678",
              "board_stream" => "PCM",
              "stream" => "Engineering",
              "father_name" => "Ravi Kumar",
              "phone" => "9876543210",
              "annual_family_income" => "Less than Rs. 1,00,000"
            }
          ]
        })

      response = json_response(conn, 200)

      assert response["totals"] == %{
               "total" => 1,
               "created" => 1,
               "duplicate_in_file" => 0,
               "already_exists" => 0,
               "rejected" => 0
             }

      assert [
               %{
                 "row_number" => 2,
                 "status" => "created",
                 "generated_student_id" => "202812345678",
                 "normalized" => %{
                   "student_name" => "Asha Kumar",
                   "g10_roll_no" => "12345678",
                   "student_id" => "202812345678"
                 }
               }
             ] = response["results"]

      student = Repo.get_by!(Student, student_id: "202812345678")
      assert student.apaar_id == "123456789012"
      assert student.g10_board == "CENTRAL BOARD OF SECONDARY EDUCATION"
      assert student.g10_roll_no == "12345678"
      assert student.grade_id == grade.id
      assert student.stream == "engineering"
      assert student.status == "enrolled"

      show_response =
        conn
        |> recycle()
        |> get("/api/student/#{student.id}")
        |> json_response(200)

      assert show_response["g10_board"] == "CENTRAL BOARD OF SECONDARY EDUCATION"
      assert show_response["g10_roll_no"] == "12345678"

      enrollment_groups =
        from(e in Dbservice.EnrollmentRecords.EnrollmentRecord,
          where: e.user_id == ^student.user_id and e.is_current == true,
          select: {e.group_type, e.group_id}
        )
        |> Repo.all()
        |> MapSet.new()

      assert MapSet.member?(enrollment_groups, {"school", school.id})
      assert MapSet.member?(enrollment_groups, {"batch", batch.id})
      assert MapSet.member?(enrollment_groups, {"grade", grade.id})

      assert Repo.aggregate(Dbservice.Groups.GroupUser, :count, :id) == 4

      audit =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT action, actor_email, school_code, program_id, upload_id, row_number, row_counts, affected_identifiers, created_values FROM lms_student_write_audits"
        ).rows

      assert [
               [
                 "student_bulk_create",
                 "pm@example.org",
                 school_code,
                 64,
                 "upload-1",
                 2,
                 row_counts,
                 affected_identifiers,
                 created_values
               ]
             ] = audit

      assert school_code == school.code
      assert row_counts["created"] == 1
      assert affected_identifiers["apaar_id"] == "123456789012"
      assert created_values["student_id"] == "202812345678"
    end

    test "marks repeated identifiers in the same upload as duplicate_in_file", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")
      before_students = Repo.aggregate(Student, :count, :id)

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{"row_number" => 2, "student_name" => "First Student"}),
            valid_row(%{"row_number" => 3, "student_name" => "Second Student"})
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["created"] == 1
      assert response["totals"]["duplicate_in_file"] == 1
      assert Enum.map(response["results"], & &1["status"]) == ["created", "duplicate_in_file"]
      assert Repo.aggregate(Student, :count, :id) == before_students + 1
    end

    test "returns already_exists for existing identifiers without updating records", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      {_user, existing_student} =
        Dbservice.UsersFixtures.student_fixture(%{
          student_id: "202812345678",
          apaar_id: "123456789012",
          g10_board: "OLD BOARD",
          g10_roll_no: "12345678"
        })

      before_users = Repo.aggregate(User, :count, :id)

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row(%{"student_name" => "Changed Name"})])
        )

      response = json_response(conn, 200)

      assert response["totals"]["already_exists"] == 1

      assert [%{"status" => "already_exists", "existing_match" => %{"student_pk_id" => id}}] =
               response["results"]

      assert id == existing_student.id
      assert Repo.aggregate(User, :count, :id) == before_users
      assert Repo.get!(Student, existing_student.id).g10_board == "OLD BOARD"
    end

    test "rejects APAAR and generated Student ID matches that point to different students", %{
      conn: conn
    } do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      Dbservice.UsersFixtures.student_fixture(%{student_id: "202812345678"})
      Dbservice.UsersFixtures.student_fixture(%{student_id: "OTHER-ID", apaar_id: "123456789012"})

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row()])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [
               %{
                 "status" => "rejected",
                 "row_errors" => [
                   "APAAR ID and generated Student ID match different existing students"
                 ]
               }
             ] = response["results"]
    end

    test "rejects rows when batch lookup is not exactly one match", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      before_students = Repo.aggregate(Student, :count, :id)

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row(%{"stream" => "missing-stream"})])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"status" => "rejected", "row_errors" => ["No matching batch found"]}] =
               response["results"]

      assert Repo.aggregate(Student, :count, :id) == before_students
    end

    test "rejects invalid category rows and audits final upload totals", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{"row_number" => 2, "student_name" => "Valid Student"}),
            valid_row(%{
              "row_number" => 3,
              "student_name" => "Invalid Student",
              "apaar_id" => "222222222222",
              "g10_roll_no" => "87654321",
              "category" => "General"
            })
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["created"] == 1
      assert response["totals"]["rejected"] == 1
      assert Enum.map(response["results"], & &1["status"]) == ["created", "rejected"]

      [[row_counts]] =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT row_counts FROM lms_student_write_audits WHERE action = 'student_bulk_create'"
        ).rows

      assert row_counts["created"] == 1
      assert row_counts["rejected"] == 1
      assert row_counts["total"] == 2
    end

    test "rejects non-CBSE Grade 10 rolls that are not 4 to 10 characters", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{
              "g10_board" => "RAJASTHAN BOARD OF SECONDARY EDUCATION",
              "g10_roll_no" => "ABC"
            })
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"row_errors" => ["Grade 10 Roll no must be 4 to 10 characters"]}] =
               response["results"]
    end

    test "rejects whitespace-only APAAR when no Grade 10 roll is present", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{
              "apaar_id" => "   ",
              "g10_roll_no" => ""
            })
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"row_errors" => ["APAAR ID or Grade 10 Roll no is required"]}] =
               response["results"]
    end

    test "rejects rows when multiple batches match grade and stream", %{conn: conn} do
      school = insert_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      {:ok, _second_batch} =
        Dbservice.Batches.create_batch_from_import(%{
          "name" => "Duplicate NVS 11 engineering",
          "batch_id" => "EnableStudents_TP_2028_engg_DUP",
          "program_id" => 64,
          "metadata" => %{"grade" => 11, "stream" => "engineering"}
        })

      before_students = Repo.aggregate(Student, :count, :id)

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row()])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"status" => "rejected", "row_errors" => ["Multiple matching batches found"]}] =
               response["results"]

      assert Repo.aggregate(Student, :count, :id) == before_students
    end
  end

  describe "student identifier schema constraints" do
    test "enforces uniqueness only when Student ID or APAAR ID is present" do
      assert {:ok, _student} = create_student(%{"student_id" => nil, "apaar_id" => nil})
      assert {:ok, _student} = create_student(%{"student_id" => nil, "apaar_id" => nil})
      assert {:ok, _student} = create_student(%{"student_id" => " ", "apaar_id" => " "})
      assert {:ok, _student} = create_student(%{"student_id" => " ", "apaar_id" => " "})

      assert {:ok, _student} =
               create_student(%{"student_id" => "SID-1", "apaar_id" => "111111111111"})

      assert {:error, changeset} =
               create_student(%{"student_id" => "SID-1", "apaar_id" => "222222222222"})

      assert {"has already been taken", _} = changeset.errors[:student_id]

      assert {:error, changeset} =
               create_student(%{"student_id" => "SID-2", "apaar_id" => "111111111111"})

      assert {"has already been taken", _} = changeset.errors[:apaar_id]
    end
  end

  defp payload(school, rows) do
    %{
      "actor" => %{
        "user_id" => 501,
        "email" => "pm@example.org",
        "login_type" => "google",
        "role" => "program_manager"
      },
      "school" => %{"code" => school.code, "udise_code" => school.udise_code},
      "program_id" => 64,
      "upload" => %{"id" => "upload-1", "filename" => "students.xlsx"},
      "academic_year" => "2026-2027",
      "start_date" => "2026-07-01",
      "rows" => rows
    }
  end

  defp valid_row(attrs \\ %{}) do
    Map.merge(
      %{
        "row_number" => 2,
        "grade" => 11,
        "student_name" => "Asha Kumar",
        "date_of_birth" => "2010-01-02",
        "gender" => "Female",
        "category" => "Gen",
        "physically_handicapped" => false,
        "apaar_id" => "123456789012",
        "g10_board" => "CENTRAL BOARD OF SECONDARY EDUCATION",
        "g10_roll_no" => "1234 5678",
        "board_stream" => "PCM",
        "stream" => "engineering",
        "father_name" => "Ravi Kumar",
        "phone" => "9876543210",
        "annual_family_income" => "Less than Rs. 1,00,000"
      },
      attrs
    )
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

  defp insert_auth_group!(name) do
    auth_group =
      Repo.get_by(AuthGroup, name: name) ||
        elem(AuthGroups.create_auth_group_from_import(%{"name" => name}), 1)

    ensure_group!("auth_group", auth_group.id)
    auth_group
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

    case existing_nvs_batches(grade, stream) do
      [batch] ->
        ensure_group!("batch", batch.id)
        batch

      [] ->
        {:ok, batch} =
          Dbservice.Batches.create_batch_from_import(%{
            "name" => "NVS #{grade} #{stream}",
            "batch_id" => "EnableStudents_TP_2028_engg_A001",
            "program_id" => 64,
            "metadata" => %{"grade" => grade, "stream" => stream}
          })

        batch
    end
  end

  defp existing_nvs_batches(grade, stream) do
    from(b in Batch,
      where:
        b.program_id == 64 and
          fragment("?->>'grade' = ?", b.metadata, ^to_string(grade)) and
          fragment("?->>'stream' = ?", b.metadata, ^stream)
    )
    |> Repo.all()
  end

  defp ensure_group!(type, child_id) do
    Repo.get_by(Group, type: type, child_id: child_id) ||
      Repo.insert!(%Group{type: type, child_id: child_id})
  end

  defp create_student(attrs) do
    user = Dbservice.UsersFixtures.user_fixture()
    Users.create_student(Map.put(attrs, "user_id", user.id))
  end
end
