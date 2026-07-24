defmodule DbserviceWeb.StudentControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  @create_attrs %{
    category: "Gen",
    father_name: "some father_name",
    father_phone: "some father_phone",
    mother_name: "some mother_name",
    mother_phone: "some mother_phone",
    stream: "medical",
    student_id: "some student id",
    physically_handicapped: false,
    family_income: "some family income",
    annual_family_income: "some annual family income",
    father_profession: "some father profession",
    father_education_level: "some father education level",
    mother_profession: "some mother profession",
    mother_education_level: "some mother education level",
    has_internet_access: "false",
    primary_smartphone_owner: "some primary smartphone owner",
    primary_smartphone_owner_profession: "some primary smartphone owner profession"
  }
  @update_attrs %{
    category: "OBC",
    father_name: "some updated father name",
    father_phone: "some updated father phone",
    mother_name: "some updated mother name",
    mother_phone: "some updated mother phone",
    stream: "pcm",
    student_id: "some updated student id",
    physically_handicapped: false,
    family_income: "some updated family income",
    annual_family_income: "some updated annual family income",
    father_profession: "some updated father profession",
    father_education_level: "some updated father education level",
    mother_profession: "some updated mother profession",
    mother_education_level: "some updated mother education level",
    has_internet_access: "false",
    primary_smartphone_owner: "some updated primary smartphone owner",
    primary_smartphone_owner_profession: "some updated primary smartphone owner profession"
  }
  @invalid_attrs %{
    category: nil,
    father_name: nil,
    father_phone: nil,
    mother_name: nil,
    mother_phone: nil,
    stream: nil,
    student_id: nil,
    physically_handicapped: nil,
    annual_family_income: nil,
    father_profession: nil,
    father_education_level: nil,
    mother_profession: nil,
    mother_education_level: nil,
    has_internet_access: nil,
    primary_smartphone_owner: nil,
    primary_smartphone_owner_profession: nil,
    user_id: nil,
    phone: "invalid phone number"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all student", %{conn: conn} do
      {_user, student} = student_fixture()
      conn = get(conn, ~p"/api/student")
      resp = json_response(conn, 200)
      assert is_list(resp)
      assert Enum.any?(resp, fn s -> s["id"] == student.id end)
      found_student = Enum.find(resp, fn s -> s["id"] == student.id end)
      assert found_student["student_id"] == student.student_id
    end
  end

  describe "create student" do
    test "renders student when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/student", @create_attrs)
      %{"id" => id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/student/#{id}")

      resp = json_response(conn, 200)
      assert resp["id"] == id
      assert resp["student_id"] == "some student id"
      assert resp["category"] == "Gen"
      assert resp["father_name"] == "some father_name"
      assert resp["stream"] == "medical"
      assert is_integer(resp["user"]["id"])
    end

    test "renders PEN in the full student response", %{conn: conn} do
      conn = post(conn, ~p"/api/student", Map.put(@create_attrs, :pen_number, "12345678901"))

      assert json_response(conn, 200)["pen_number"] == "12345678901"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/student", @invalid_attrs)
      assert json_response(conn, 400)["error"] != nil
    end
  end

  describe "update student" do
    setup [:create_student]

    test "renders student when data is valid", %{conn: conn, student: student} do
      user = user_fixture()
      attrs = Map.put(@update_attrs, :user_id, user.id)

      conn = put(conn, ~p"/api/student/#{student.id}", attrs)
      %{"id" => id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/student/#{id}")
      resp = json_response(conn, 200)

      assert resp["id"] == id
      assert resp["student_id"] == "some updated student id"
      assert resp["category"] == "OBC"
      assert resp["father_name"] == "some updated father name"
      assert resp["stream"] == "pcm"
      assert resp["family_income"] == "some updated family income"
      assert resp["annual_family_income"] == "some updated annual family income"
      assert is_integer(resp["user"]["id"])
    end

    test "renders errors when data is invalid", %{conn: conn, student: student} do
      conn = put(conn, ~p"/api/student/#{student.id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "ends an active Holistic Mapping when status becomes dropout", %{
      conn: conn,
      student: student
    } do
      mapping_id = insert_active_mapping(student.id)

      conn = put(conn, ~p"/api/student/#{student.id}", %{status: "dropout"})

      assert json_response(conn, 200)["status"] == "dropout"

      assert Dbservice.Repo.query!(
               "SELECT end_reason FROM holistic_mentorship_mentor_mentee_mappings WHERE id = $1",
               [mapping_id]
             ).rows == [["student_dropout"]]
    end
  end

  describe "delete student" do
    setup [:create_student]

    test "deletes chosen student", %{conn: conn, student: student} do
      conn = delete(conn, ~p"/api/student/#{student.id}")
      assert response(conn, 204)

      # Verify student is actually deleted
      conn = get(conn, ~p"/api/student/#{student.id}")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_student(_) do
    {_user, student} = student_fixture()
    %{student: student}
  end

  defp insert_active_mapping(student_id) do
    mentor = user_fixture()

    [[school_id]] =
      Dbservice.Repo.query!(
        "INSERT INTO school (inserted_at, updated_at) VALUES (now(), now()) RETURNING id"
      ).rows

    [[product_id]] =
      Dbservice.Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('HTTP Cleanup', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Dbservice.Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('HTTP Cleanup', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    [[mapping_id]] =
      Dbservice.Repo.query!(
        """
        INSERT INTO holistic_mentorship_mentor_mentee_mappings
          (student_id, mentor_user_id, school_id, program_id, academic_year, started_at,
           assignment_source)
        VALUES ($1, $2, $3, $4, '2026-27', timezone('UTC', now()), 'af_lms')
        RETURNING id
        """,
        [student_id, mentor.id, school_id, program_id]
      ).rows

    mapping_id
  end
end
