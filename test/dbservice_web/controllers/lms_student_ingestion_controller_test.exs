defmodule DbserviceWeb.LmsStudentIngestionControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  alias Dbservice.AuthGroups
  alias Dbservice.Batches.Batch
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Products.Product
  alias Dbservice.Repo
  alias Dbservice.Schools.School
  alias Dbservice.Users
  alias Dbservice.Users.User
  alias Dbservice.Users.Student

  describe "POST /api/lms/students/bulk-create-with-enrollments" do
    test "accepts a legacy actor without a linked user id", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      request =
        school
        |> payload([valid_pen_row("12345678901", %{})])
        |> put_in(["actor", "user_id"], nil)

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", request)
        |> json_response(200)

      assert response["totals"]["created"] == 1
      assert Repo.one(from a in Dbservice.LmsStudentWriteAudit, select: a.actor_user_id) == nil
    end

    test "creates a PEN-only student for a current NVS program without Centre eligibility", %{
      conn: conn
    } do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{
              "pen_number" => "12345678901",
              "apaar_id" => nil,
              "g10_board" => nil,
              "g10_roll_no" => nil,
              "stream" => "NDA"
            })
          ])
        )

      assert %{
               "totals" => %{"created" => 1},
               "results" => [
                 %{
                   "status" => "created",
                   "generated_student_id" => nil,
                   "normalized" => %{"pen_number" => "12345678901"}
                 }
               ]
             } = json_response(conn, 200)

      student = Repo.get_by!(Student, pen_number: "12345678901")
      assert student.student_id == nil
      assert student.apaar_id == nil
      assert student.stream == "nda"
    end

    test "missing actor metadata rolls back student creation", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      request =
        school
        |> payload([valid_pen_row("12345678909", %{"stream" => "nda"})])
        |> put_in(["actor", "email"], nil)

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", request)
        |> json_response(200)

      assert response["totals"] == %{
               "total" => 1,
               "created" => 0,
               "duplicate_in_file" => 0,
               "already_exists" => 0,
               "rejected" => 1
             }

      refute Repo.get_by(Student, pen_number: "12345678909")
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == 0
    end

    test "requires a valid PEN or Grade 10 Roll Number and does not use APAAR as identity", %{
      conn: conn
    } do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      rows = [
        valid_row(%{
          "row_number" => 2,
          "pen_number" => "01234567890",
          "apaar_id" => nil,
          "g10_roll_no" => nil,
          "stream" => "nda"
        }),
        valid_row(%{
          "row_number" => 3,
          "pen_number" => "12345",
          "apaar_id" => nil,
          "g10_roll_no" => nil,
          "stream" => "nda"
        }),
        valid_row(%{
          "row_number" => 4,
          "pen_number" => 12_345_678_901,
          "apaar_id" => nil,
          "g10_roll_no" => "87654321",
          "stream" => "nda"
        }),
        valid_row(%{
          "row_number" => 5,
          "pen_number" => nil,
          "apaar_id" => "123456789012",
          "g10_roll_no" => nil,
          "stream" => "nda"
        }),
        valid_pen_row("12345678909", %{
          "row_number" => 6,
          "g10_board" => "State Board"
        }),
        valid_row(%{
          "row_number" => 7,
          "pen_number" => nil,
          "g10_board" => nil,
          "g10_roll_no" => "12345678",
          "stream" => "nda"
        })
      ]

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", payload(school, rows))
        |> json_response(200)

      assert response["totals"]["rejected"] == 6

      assert Enum.map(response["results"], & &1["row_errors"]) == [
               ["PEN Number must be exactly 11 digits and cannot start with zero"],
               ["PEN Number must be exactly 11 digits and cannot start with zero"],
               ["PEN Number must be exactly 11 digits and cannot start with zero"],
               ["PEN Number or Grade 10 Roll no is required"],
               ["Grade 10 Board must be CBSE or Others"],
               ["Grade 10 Board must be CBSE or Others"]
             ]
    end

    test "rejects leading-zero phone and CBSE roll numbers", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{"phone" => "0876543210"}),
            valid_row(%{
              "row_number" => 3,
              "pen_number" => "12345678902",
              "g10_roll_no" => "02345678"
            })
          ])
        )
        |> json_response(200)

      assert response["totals"]["rejected"] == 2

      assert Enum.map(response["results"], & &1["row_errors"]) == [
               ["Parents Phone Number must be exactly 10 digits and cannot start with zero"],
               ["CBSE Grade 10 Roll no must be exactly 8 digits and cannot start with zero"]
             ]
    end

    test "normalizes canonical board rolls and derives Student ID from the academic year", %{
      conn: conn
    } do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      rows = [
        valid_row(%{
          "row_number" => 2,
          "pen_number" => nil,
          "apaar_id" => nil,
          "g10_board" => "CBSE",
          "g10_roll_no" => "11234567",
          "stream" => "nda"
        }),
        valid_row(%{
          "row_number" => 3,
          "pen_number" => nil,
          "apaar_id" => nil,
          "g10_board" => "Others",
          "g10_roll_no" => "00-ab 12/34",
          "stream" => "nda"
        }),
        valid_row(%{
          "row_number" => 4,
          "pen_number" => nil,
          "apaar_id" => nil,
          "g10_board" => "State Board",
          "g10_roll_no" => "12345678",
          "stream" => "nda"
        })
      ]

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", payload(school, rows))
        |> json_response(200)

      assert response["totals"] |> Map.take(["created", "rejected"]) == %{
               "created" => 2,
               "rejected" => 1
             }

      assert Enum.map(response["results"], &{&1["status"], &1["generated_student_id"]}) == [
               {"created", "202811234567"},
               {"created", "2028AB1234"},
               {"rejected", "202812345678"}
             ]

      cbse = Repo.get_by!(Student, student_id: "202811234567")
      assert {cbse.g10_board, cbse.g10_roll_no} == {"CBSE", "11234567"}

      other = Repo.get_by!(Student, student_id: "2028AB1234")
      assert {other.g10_board, other.g10_roll_no} == {nil, "AB1234"}

      assert Enum.at(response["results"], 2)["row_errors"] == [
               "Grade 10 Board must be CBSE or Others"
             ]
    end

    test "rejects an invalid academic year without creating a student", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      params =
        school
        |> payload([valid_pen_row("12345678901", %{})])
        |> Map.put("academic_year", "2026-2028")

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", params)
        |> json_response(200)

      assert [%{"status" => "rejected", "row_errors" => ["Academic year must be YYYY-YYYY"]}] =
               response["results"]

      refute Repo.get_by(Student, pen_number: "12345678901")
    end

    test "normalizes supported profile values and rejects invalid NVS combinations", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      rows = [
        valid_pen_row("12345678901", %{
          "row_number" => 2,
          "gender" => "Others",
          "date_of_birth" => "02/01/2010",
          "category" => "PWD-OBC",
          "physically_handicapped" => true
        }),
        valid_pen_row("12345678902", %{
          "row_number" => 3,
          "gender" => "Other",
          "date_of_birth" => "03-02-2011"
        }),
        valid_pen_row("12345678903", %{
          "row_number" => 4,
          "category" => "PWD-Gen",
          "physically_handicapped" => false
        }),
        valid_pen_row("12345678904", %{
          "row_number" => 5,
          "category" => "Gen",
          "physically_handicapped" => true
        }),
        valid_pen_row("12345678905", %{"row_number" => 6, "gender" => "Unknown"}),
        valid_pen_row("12345678906", %{
          "row_number" => 7,
          "date_of_birth" => "31/02/2010"
        }),
        valid_pen_row("12345678907", %{
          "row_number" => 8,
          "date_of_birth" => "1999-12-31"
        }),
        valid_pen_row("12345678908", %{
          "row_number" => 9,
          "date_of_birth" => "2016-01-01"
        })
      ]

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", payload(school, rows))
        |> json_response(200)

      assert response["totals"] |> Map.take(["created", "rejected"]) == %{
               "created" => 2,
               "rejected" => 6
             }

      first = Repo.get_by!(Student, pen_number: "12345678901") |> Repo.preload(:user)
      assert {first.category, first.physically_handicapped} == {"PWD-OBC", true}
      assert {first.user.gender, first.user.date_of_birth} == {"Other", ~D[2010-01-02]}

      second = Repo.get_by!(Student, pen_number: "12345678902") |> Repo.preload(:user)
      assert {second.user.gender, second.user.date_of_birth} == {"Other", ~D[2011-02-03]}
      assert Enum.all?(Enum.drop(response["results"], 2), &(&1["status"] == "rejected"))
    end

    test "returns and audits all identifiers for a created student", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      batch = insert_nvs_batch!(11, "nda")

      row =
        valid_pen_row("12345678901", %{
          "g10_board" => "CBSE",
          "g10_roll_no" => "11234567"
        })

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", payload(school, [row]))
        |> json_response(200)

      assert [result] = response["results"]
      assert result["status"] == "created"
      assert result["student_id"] == "202811234567"
      assert result["pen_number"] == "12345678901"
      assert result["apaar_id"] == nil
      assert is_integer(result["student_pk_id"])
      assert is_integer(result["user_id"])
      assert result["batch_pk_id"] == batch.id
      assert is_integer(result["audit_id"])

      assert result["normalized"]
             |> Map.take([
               "g10_board",
               "gender",
               "date_of_birth",
               "category",
               "physically_handicapped",
               "stream",
               "g12_graduating_year"
             ]) == %{
               "g10_board" => "CBSE",
               "gender" => "Female",
               "date_of_birth" => "2010-01-02",
               "category" => "Gen",
               "physically_handicapped" => false,
               "stream" => "nda",
               "g12_graduating_year" => 2028
             }

      audit = Repo.get!(Dbservice.LmsStudentWriteAudit, result["audit_id"])

      assert audit.affected_identifiers == %{
               "student_pk_id" => result["student_pk_id"],
               "user_id" => result["user_id"],
               "student_id" => "202811234567",
               "pen_number" => "12345678901",
               "apaar_id" => nil,
               "g10_roll_no" => "11234567"
             }

      assert audit.created_values["batch_pk_id"] == batch.id
      assert audit.created_values["school_id"] == school.id
      assert audit.created_values["grade_id"] == Repo.get_by!(Grade, number: 11).id
      assert audit.created_values["gender"] == "Female"
      assert audit.created_values["category"] == "Gen"
      assert audit.created_values["stream"] == "nda"
      assert audit.row_counts["created"] == 1
      assert audit.row_counts["total"] == 1
    end

    test "rolls back the whole row and returns a safe error when enrollment fails", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      Repo.update_all(from(g in Group, where: g.type == "auth_group"),
        set: [type: "auth_group_disabled"]
      )

      before_users = Repo.aggregate(User, :count, :id)
      before_students = Repo.aggregate(Student, :count, :id)
      before_audits = Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id)

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_pen_row("12345678901", %{})])
        )
        |> json_response(200)

      assert [%{"status" => "rejected", "row_errors" => ["Student could not be created"]}] =
               response["results"]

      assert Repo.aggregate(User, :count, :id) == before_users
      assert Repo.aggregate(Student, :count, :id) == before_students
      assert Repo.aggregate(Dbservice.LmsStudentWriteAudit, :count, :id) == before_audits
    end

    test "classifies duplicate, existing, and conflicting PEN identifiers safely", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      {_user, existing_pen} =
        Dbservice.UsersFixtures.student_fixture(%{
          student_id: nil,
          pen_number: "12345678901",
          apaar_id: "998877665544",
          g10_roll_no: "HIST1234"
        })

      Dbservice.UsersFixtures.student_fixture(%{student_id: "202812345678"})

      Dbservice.UsersFixtures.student_fixture(%{
        student_id: "OTHER-ID",
        pen_number: "12345678902"
      })

      rows = [
        valid_pen_row("12345678901", %{"row_number" => 2}),
        valid_pen_row("12345678902", %{
          "row_number" => 3,
          "g10_board" => "CBSE",
          "g10_roll_no" => "12345678"
        }),
        valid_pen_row("12345678903", %{"row_number" => 4}),
        valid_pen_row("12345678903", %{"row_number" => 5})
      ]

      response =
        conn
        |> post("/api/lms/students/bulk-create-with-enrollments", payload(school, rows))
        |> json_response(200)

      assert Enum.map(response["results"], & &1["status"]) == [
               "already_exists",
               "rejected",
               "created",
               "duplicate_in_file"
             ]

      existing_pen_id = existing_pen.id
      existing_user_id = existing_pen.user_id

      assert %{
               "student_pk_id" => ^existing_pen_id,
               "user_id" => ^existing_user_id,
               "student_id" => nil,
               "pen_number" => "12345678901",
               "apaar_id" => "998877665544",
               "g10_roll_no" => "HIST1234",
               "matched_identifier" => "PEN Number"
             } = Enum.at(response["results"], 0)["existing_match"]

      assert Enum.at(response["results"], 1)["row_errors"] == [
               "PEN Number and generated Student ID match different existing students"
             ]
    end

    test "rejects a new PEN when the generated Student ID belongs to another PEN", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")

      Dbservice.UsersFixtures.student_fixture(%{
        student_id: "202812345678",
        pen_number: "12345678909"
      })

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_pen_row("12345678908", %{
              "g10_board" => "CBSE",
              "g10_roll_no" => "12345678"
            })
          ])
        )
        |> json_response(200)

      assert [
               %{
                 "status" => "rejected",
                 "row_errors" => [
                   "PEN Number conflicts with the existing generated Student ID"
                 ]
               }
             ] = response["results"]
    end

    test "concurrent retries create one complete row and return already_exists for the loser", %{
      conn: conn
    } do
      school = insert_school!(%{program_ids: []})
      ensure_nvs_program!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "nda")
      params = payload(school, [valid_pen_row("12345678901", %{})])
      parent = self()

      tasks =
        Enum.map(1..2, fn _ ->
          Task.async(fn ->
            send(parent, {:ready, self()})
            receive do: (:go -> :ok)

            conn
            |> post("/api/lms/students/bulk-create-with-enrollments", params)
            |> json_response(200)
          end)
        end)

      pids =
        Enum.map(tasks, fn _ ->
          assert_receive {:ready, pid}
          pid
        end)

      Enum.each(pids, &send(&1, :go))
      responses = Enum.map(tasks, &Task.await(&1, 5_000))

      assert responses
             |> Enum.map(&get_in(&1, ["results", Access.at(0), "status"]))
             |> Enum.sort() ==
               ["already_exists", "created"]

      student = Repo.get_by!(Student, pen_number: "12345678901")
      assert Repo.aggregate(from(s in Student, where: s.pen_number == "12345678901"), :count) == 1
      assert Repo.aggregate(from(u in User, where: u.id == ^student.user_id), :count) == 1

      assert Repo.aggregate(
               from(a in Dbservice.LmsStudentWriteAudit, where: a.upload_id == "upload-1"),
               :count
             ) == 1
    end

    test "creates one NVS student with derived identity, enrollments, and audit", %{conn: conn} do
      school = insert_eligible_school!()
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
              "pen_number" => "12345678901",
              "g10_board" => "CBSE",
              "g10_roll_no" => "12345678",
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
      assert student.pen_number == "12345678901"
      assert student.g10_board == "CBSE"
      assert student.g10_roll_no == "12345678"
      assert student.grade_id == grade.id
      assert student.stream == "engineering"
      assert student.status == "enrolled"

      show_response =
        conn
        |> recycle()
        |> get("/api/student/#{student.id}")
        |> json_response(200)

      assert show_response["g10_board"] == "CBSE"
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
      assert affected_identifiers["pen_number"] == "12345678901"
      assert created_values["student_id"] == "202812345678"
    end

    test "rejects a program that is not a current NVS program", %{conn: conn} do
      school = insert_school!(%{program_ids: []})
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      Repo.get!(Dbservice.Programs.Program, 64)
      |> Ecto.Changeset.change(is_current: false)
      |> Repo.update!()

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row()])
        )

      assert [%{"row_errors" => ["Program must be a current NVS program"]}] =
               json_response(conn, 200)["results"]
    end

    test "marks repeated identifiers in the same upload as duplicate_in_file", %{conn: conn} do
      school = insert_eligible_school!()
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
      school = insert_eligible_school!()

      existing_school =
        insert_school!(%{
          code: "JNV999",
          name: "JNV Other",
          udise_code: "99999999999",
          district_code: "D999",
          district: "Jaipur",
          state_code: "RJ",
          state: "Rajasthan"
        })

      insert_auth_group!("EnableStudents")
      grade = insert_grade!(11)
      batch = insert_nvs_batch!(11, "engineering")

      {user, existing_student} =
        Dbservice.UsersFixtures.student_fixture(%{
          student_id: "202812345678",
          pen_number: "12345678901",
          g10_board: "OLD BOARD",
          g10_roll_no: "12345678",
          grade_id: grade.id,
          stream: "engineering"
        })

      for {group_id, group_type} <- [{existing_school.id, "school"}, {batch.id, "batch"}] do
        Repo.insert!(%EnrollmentRecord{
          user_id: user.id,
          group_id: group_id,
          group_type: group_type,
          academic_year: "2027-2028",
          start_date: ~D[2027-04-01]
        })
      end

      before_users = Repo.aggregate(User, :count, :id)

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row(%{"student_name" => "Changed Name"})])
        )

      response = json_response(conn, 200)

      assert response["totals"]["already_exists"] == 1

      assert [
               %{
                 "status" => "already_exists",
                 "existing_match" => %{
                   "student_pk_id" => id,
                   "matched_identifier" => "Student ID + PEN Number",
                   "student_name" => "some first name some last name",
                   "school_name" => "JNV Other",
                   "school_code" => "JNV999",
                   "udise_code" => "99999999999",
                   "district" => "Jaipur",
                   "state" => "Rajasthan",
                   "grade" => 11,
                   "program" => "JNV NVS",
                   "stream" => "engineering"
                 }
               }
             ] =
               response["results"]

      assert id == existing_student.id
      assert Repo.aggregate(User, :count, :id) == before_users
      assert Repo.get!(Student, existing_student.id).g10_board == "OLD BOARD"
    end

    test "rejects rows when batch lookup is not exactly one match", %{conn: conn} do
      school = insert_eligible_school!()
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

    test "rejects a matching batch without a batch group", %{conn: conn} do
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      batch = insert_nvs_batch!(11, "nda")
      Repo.delete_all(from(g in Group, where: g.type == "batch" and g.child_id == ^batch.id))

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_pen_row("12345678901", %{})])
        )
        |> json_response(200)

      assert [%{"status" => "rejected", "row_errors" => ["Batch group not found"]}] =
               response["results"]

      refute Repo.get_by(Student, pen_number: "12345678901")
    end

    test "rejects invalid category rows and audits final upload totals", %{conn: conn} do
      school = insert_eligible_school!()
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
              "pen_number" => "12345678902",
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
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{
              "g10_board" => "Others",
              "g10_roll_no" => "ABC"
            })
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"row_errors" => ["Grade 10 Roll no must be 4 to 10 characters"]}] =
               response["results"]
    end

    test "trims accidental whitespace around CBSE and Others boards", %{conn: conn} do
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{"g10_board" => " CBSE "}),
            valid_row(%{
              "pen_number" => "12345678902",
              "g10_board" => " Others ",
              "g10_roll_no" => "00-ab 12/34"
            })
          ])
        )
        |> json_response(200)

      assert response["totals"]["created"] == 2
      assert Repo.get_by!(Student, pen_number: "12345678901").g10_board == "CBSE"
      assert Repo.get_by!(Student, pen_number: "12345678902").g10_board == nil
    end

    test "normalizes a blank Grade 10 board to null in storage, response, and audit", %{
      conn: conn
    } do
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [valid_row(%{"g10_board" => "", "g10_roll_no" => ""})])
        )
        |> json_response(200)

      assert response["totals"]["created"] == 1
      assert get_in(hd(response["results"]), ["normalized", "g10_board"]) == nil

      student = Repo.get_by!(Student, pen_number: "12345678901")
      assert student.g10_board == nil

      [[created_values]] =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT created_values FROM lms_student_write_audits WHERE action = 'student_bulk_create'"
        ).rows

      assert created_values["g10_board"] == nil
    end

    test "rejects a supplied Others roll that normalizes to empty", %{conn: conn} do
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      response =
        conn
        |> post(
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{"g10_board" => "Others", "g10_roll_no" => "00-00"})
          ])
        )
        |> json_response(200)

      assert [%{"row_errors" => ["Grade 10 Roll no must be 4 to 10 characters"]}] =
               response["results"]

      refute Repo.get_by(Student, pen_number: "12345678901")
    end

    test "rejects whitespace-only PEN when no Grade 10 roll is present", %{conn: conn} do
      school = insert_eligible_school!()
      insert_auth_group!("EnableStudents")
      insert_grade!(11)
      insert_nvs_batch!(11, "engineering")

      conn =
        post(
          conn,
          "/api/lms/students/bulk-create-with-enrollments",
          payload(school, [
            valid_row(%{
              "pen_number" => "   ",
              "g10_roll_no" => ""
            })
          ])
        )

      response = json_response(conn, 200)

      assert response["totals"]["rejected"] == 1

      assert [%{"row_errors" => ["PEN Number or Grade 10 Roll no is required"]}] =
               response["results"]
    end

    test "rejects rows when multiple batches match grade and stream", %{conn: conn} do
      school = insert_eligible_school!()
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
    test "allows duplicate Student IDs while keeping APAAR ID unique" do
      assert {:ok, _student} = create_student(%{"student_id" => nil, "apaar_id" => nil})
      assert {:ok, _student} = create_student(%{"student_id" => nil, "apaar_id" => nil})
      assert {:ok, _student} = create_student(%{"student_id" => " ", "apaar_id" => " "})
      assert {:ok, _student} = create_student(%{"student_id" => " ", "apaar_id" => " "})

      assert {:ok, _student} =
               create_student(%{"student_id" => "SID-1", "apaar_id" => "111111111111"})

      assert {:ok, _student} =
               create_student(%{"student_id" => "SID-1", "apaar_id" => "222222222222"})

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
        "pen_number" => "12345678901",
        "g10_board" => "CBSE",
        "g10_roll_no" => "12345678",
        "board_stream" => "PCM",
        "stream" => "engineering",
        "father_name" => "Ravi Kumar",
        "phone" => "9876543210",
        "annual_family_income" => "Less than Rs. 1,00,000"
      },
      attrs
    )
  end

  defp valid_pen_row(pen_number, attrs) do
    valid_row(
      Map.merge(
        %{
          "pen_number" => pen_number,
          "apaar_id" => nil,
          "g10_board" => nil,
          "g10_roll_no" => nil,
          "stream" => "nda"
        },
        attrs
      )
    )
  end

  defp insert_school!(attrs) do
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
        program_ids: [64]
      }
      |> Map.merge(attrs)
      |> then(&struct!(School, &1))
      |> Repo.insert!()

    Repo.insert!(%Group{type: "school", child_id: school.id})
    school
  end

  defp insert_eligible_school!(attrs \\ %{}) do
    school = insert_school!(attrs)
    ensure_nvs_program!()
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
    ensure_nvs_program!()

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

  defp ensure_nvs_program! do
    Repo.get(Dbservice.Programs.Program, 64) ||
      Repo.insert!(%Dbservice.Programs.Program{
        id: 64,
        name: "JNV NVS",
        product_id: ensure_nvs_product!().id,
        target_outreach: 100,
        donor: "NVS",
        state: "India",
        model: "Lakshya",
        is_current: true
      })
  end

  defp ensure_nvs_product! do
    Repo.get_by(Product, code: "TP-Async") ||
      Dbservice.ProductsFixtures.product_fixture(%{code: "TP-Async"})
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
