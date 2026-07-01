defmodule DbserviceWeb.LmsStudentDocumentControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.LmsStudentDocuments

  @page %{
    "s3_key" => "students/1/research_consent/abc/page-1.jpg",
    "page_number" => 1,
    "mime_type" => "image/jpeg",
    "byte_size" => 245_678
  }

  setup %{conn: conn} do
    {_user, student} = student_fixture()

    create_attrs = %{
      student_id: student.id,
      document_type: "research_consent",
      pages: [@page],
      metadata: %{"consent_version" => "v1"},
      uploaded_by: "teacher@avantifellows.org"
    }

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     student: student,
     create_attrs: create_attrs}
  end

  describe "create document" do
    test "renders document when data is valid", %{conn: conn, create_attrs: attrs} do
      conn = post(conn, ~p"/api/lms-student-document", attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/lms-student-document/#{id}")
      resp = json_response(conn, 200)
      assert resp["id"] == id
      assert resp["document_type"] == "research_consent"
      assert resp["uploaded_by"] == "teacher@avantifellows.org"
      assert length(resp["pages"]) == 1
    end

    test "accepts any non-empty document_type (free string)", %{conn: conn, create_attrs: attrs} do
      conn = post(conn, ~p"/api/lms-student-document", %{attrs | document_type: "anything_goes"})
      resp = json_response(conn, 201)
      assert resp["document_type"] == "anything_goes"
    end

    test "rejects blank document_type", %{conn: conn, create_attrs: attrs} do
      conn = post(conn, ~p"/api/lms-student-document", %{attrs | document_type: ""})
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "rejects oversized document_type (>64 chars)", %{conn: conn, create_attrs: attrs} do
      conn =
        post(conn, ~p"/api/lms-student-document", %{
          attrs
          | document_type: String.duplicate("x", 65)
        })

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "rejects empty pages array", %{conn: conn, create_attrs: attrs} do
      conn = post(conn, ~p"/api/lms-student-document", %{attrs | pages: []})
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "rejects malformed page entry", %{conn: conn, create_attrs: attrs} do
      bad_page = %{"s3_key" => "x", "page_number" => "not-an-int"}
      conn = post(conn, ~p"/api/lms-student-document", %{attrs | pages: [bad_page]})
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "rejects missing student_id", %{conn: conn, create_attrs: attrs} do
      conn = post(conn, ~p"/api/lms-student-document", Map.delete(attrs, :student_id))
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "index" do
    test "lists documents filtered by student_id", %{
      conn: conn,
      student: student,
      create_attrs: attrs
    } do
      {:ok, _doc} = LmsStudentDocuments.create_lms_student_document(attrs)
      {_user, other_student} = student_fixture(%{student_id: "other student id"})

      {:ok, _other} =
        LmsStudentDocuments.create_lms_student_document(%{attrs | student_id: other_student.id})

      conn = get(conn, ~p"/api/lms-student-document?student_id=#{student.id}")
      resp = json_response(conn, 200)
      assert is_list(resp)
      assert Enum.all?(resp, fn d -> d["student_id"] == student.id end)
      assert length(resp) == 1
    end

    test "excludes soft-deleted documents", %{conn: conn, student: student, create_attrs: attrs} do
      {:ok, doc} = LmsStudentDocuments.create_lms_student_document(attrs)
      {:ok, _} = LmsStudentDocuments.soft_delete_lms_student_document(doc)

      conn = get(conn, ~p"/api/lms-student-document?student_id=#{student.id}")
      resp = json_response(conn, 200)
      assert resp == []
    end
  end

  describe "show document" do
    test "renders document", %{conn: conn, create_attrs: attrs} do
      {:ok, doc} = LmsStudentDocuments.create_lms_student_document(attrs)
      conn = get(conn, ~p"/api/lms-student-document/#{doc.id}")
      resp = json_response(conn, 200)
      assert resp["id"] == doc.id
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/lms-student-document/999999")
      assert json_response(conn, 404)["error"] == "Document not found"
    end

    test "404 for soft-deleted document", %{conn: conn, create_attrs: attrs} do
      {:ok, doc} = LmsStudentDocuments.create_lms_student_document(attrs)
      {:ok, _} = LmsStudentDocuments.soft_delete_lms_student_document(doc)
      conn = get(conn, ~p"/api/lms-student-document/#{doc.id}")
      assert json_response(conn, 404)["error"] == "Document not found"
    end
  end

  describe "delete document" do
    test "soft-deletes the document", %{conn: conn, create_attrs: attrs} do
      {:ok, doc} = LmsStudentDocuments.create_lms_student_document(attrs)
      conn = delete(conn, ~p"/api/lms-student-document/#{doc.id}")
      assert response(conn, 204)
      assert LmsStudentDocuments.get_lms_student_document(doc.id) == nil
    end

    test "404 for unknown id", %{conn: conn} do
      conn = delete(conn, ~p"/api/lms-student-document/999999")
      assert json_response(conn, 404)["error"] == "Document not found"
    end
  end
end
