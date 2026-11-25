defmodule Dbservice.LmsStudentDocumentExamLinkTest do
  use Dbservice.DataCase

  import Dbservice.UsersFixtures

  alias Dbservice.LmsStudentDocuments
  alias Dbservice.LmsStudentDocuments.LmsStudentDocument
  alias Dbservice.Repo
  alias Dbservice.StudentExamRecords

  @ack "exam_acknowledgement"

  @page %{
    "s3_key" => "lms-documents/students/1/exam_acknowledgement/abc/page-1.pdf",
    "page_number" => 1,
    "mime_type" => "application/pdf",
    "byte_size" => 120_000
  }

  defp exam(name) do
    {:ok, exam} = Dbservice.Exams.create_exam(%{name: "#{name} #{System.unique_integer()}"})
    exam
  end

  defp registration(student, exam, sessions) do
    {:ok, record} =
      StudentExamRecords.create_student_exam_record(%{
        student_id: student.id,
        exam_id: exam.id,
        application_number: "APP#{System.unique_integer([:positive])}",
        sessions_applied: sessions
      })

    record
  end

  defp ack_attrs(student, record, session) do
    %{
      student_id: student.id,
      document_type: @ack,
      pages: [@page],
      uploaded_by: "teacher@avantifellows.org",
      student_exam_record_id: record.id,
      exam_session: session
    }
  end

  defp active_ids(record) do
    LmsStudentDocuments.list_lms_student_documents(%{"student_exam_record_id" => record.id})
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  setup do
    {_user, student} = student_fixture()
    jee = registration(student, exam("JEE Mains"), [1, 2])
    neet = registration(student, exam("NEET"), nil)
    %{student: student, jee: jee, neet: neet}
  end

  describe "creating an exam acknowledgement" do
    test "stores one per applied session", %{student: student, jee: jee} do
      assert {:ok, %LmsStudentDocument{exam_session: 1} = s1} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 1))

      assert {:ok, %LmsStudentDocument{exam_session: 2} = s2} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 2))

      assert active_ids(jee) == Enum.sort([s1.id, s2.id])
    end

    test "stores one with no session for an exam without sessions", %{
      student: student,
      neet: neet
    } do
      assert {:ok, %LmsStudentDocument{exam_session: nil, student_exam_record_id: id}} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, neet, nil))

      assert id == neet.id
    end

    test "replaces the current one for the same session", %{student: student, jee: jee} do
      {:ok, first} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 1))
      {:ok, other} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 2))
      {:ok, second} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 1))

      assert active_ids(jee) == Enum.sort([other.id, second.id])
      assert Repo.get!(LmsStudentDocument, first.id).deleted_at
    end

    test "keeps the current one when the replacement is refused", %{student: student, jee: jee} do
      {:ok, first} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 1))

      assert {:error, _changeset} =
               LmsStudentDocuments.create_lms_student_document(%{
                 ack_attrs(student, jee, 1)
                 | pages: []
               })

      assert active_ids(jee) == [first.id]
    end

    test "requires the registration", %{student: student, jee: jee} do
      attrs = Map.delete(ack_attrs(student, jee, 1), :student_exam_record_id)
      assert {:error, changeset} = LmsStudentDocuments.create_lms_student_document(attrs)
      assert changeset.errors[:student_exam_record_id]
    end

    test "refuses a registration that does not exist", %{student: student, jee: jee} do
      attrs = %{ack_attrs(student, jee, 1) | student_exam_record_id: jee.id + 1_000_000}
      assert {:error, changeset} = LmsStudentDocuments.create_lms_student_document(attrs)
      assert {"does not exist", _} = changeset.errors[:student_exam_record_id]
    end

    test "refuses another student's registration", %{jee: jee} do
      {_user, other} = student_fixture(%{student_id: "other student id"})

      assert {:error, changeset} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(other, jee, 1))

      assert {"belongs to another student", _} = changeset.errors[:student_exam_record_id]
    end

    test "refuses a session the student did not apply for", %{student: student} do
      jee_s1 = registration(student, exam("JEE Mains"), [1])

      assert {:error, changeset} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee_s1, 2))

      assert changeset.errors[:exam_session]
    end

    test "refuses a missing session when the student applied for sessions", %{
      student: student,
      jee: jee
    } do
      assert {:error, changeset} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, nil))

      assert changeset.errors[:exam_session]
    end

    test "refuses a session on an exam without sessions", %{student: student, neet: neet} do
      assert {:error, changeset} =
               LmsStudentDocuments.create_lms_student_document(ack_attrs(student, neet, 1))

      assert changeset.errors[:exam_session]
    end

    test "refuses a registration on any other document type", %{student: student, jee: jee} do
      attrs = %{ack_attrs(student, jee, 1) | document_type: "income_certificate"}
      assert {:error, changeset} = LmsStudentDocuments.create_lms_student_document(attrs)
      assert changeset.errors[:student_exam_record_id]
    end

    test "leaves other document types untouched", %{student: student} do
      assert {:ok, %LmsStudentDocument{student_exam_record_id: nil, exam_session: nil}} =
               LmsStudentDocuments.create_lms_student_document(%{
                 student_id: student.id,
                 document_type: "income_certificate",
                 pages: [@page],
                 uploaded_by: "teacher@avantifellows.org"
               })
    end

    test "the database holds one current document per session", %{student: student, jee: jee} do
      changeset = LmsStudentDocument.changeset(%LmsStudentDocument{}, ack_attrs(student, jee, 1))
      assert {:ok, _} = Repo.insert(changeset)
      assert {:error, failed} = Repo.insert(changeset)
      assert failed.errors[:student_exam_record_id]
    end
  end

  describe "changing the registration" do
    setup %{student: student, jee: jee} do
      {:ok, s1} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 1))
      {:ok, s2} = LmsStudentDocuments.create_lms_student_document(ack_attrs(student, jee, 2))
      %{s1: s1, s2: s2}
    end

    test "dropping a session retires that session's acknowledgement", %{jee: jee, s1: s1} do
      {:ok, _} = StudentExamRecords.update_student_exam_record(jee, %{sessions_applied: [1]})
      assert active_ids(jee) == [s1.id]
    end

    test "clearing the sessions retires every session's acknowledgement", %{jee: jee} do
      {:ok, _} = StudentExamRecords.update_student_exam_record(jee, %{sessions_applied: []})
      assert active_ids(jee) == []
    end

    test "an update that leaves the sessions alone keeps them", %{jee: jee, s1: s1, s2: s2} do
      {:ok, _} =
        StudentExamRecords.update_student_exam_record(jee, %{application_number: "NEW123"})

      assert active_ids(jee) == Enum.sort([s1.id, s2.id])
    end

    test "moving it to another exam retires every acknowledgement", %{jee: jee} do
      {:ok, _} =
        StudentExamRecords.update_student_exam_record(jee, %{exam_id: exam("CUET").id})

      assert active_ids(jee) == []
    end

    test "a refused update keeps the acknowledgements", %{jee: jee, s1: s1, s2: s2} do
      assert {:error, _} =
               StudentExamRecords.update_student_exam_record(jee, %{
                 sessions_applied: [1],
                 exam_phone: "not digits"
               })

      assert active_ids(jee) == Enum.sort([s1.id, s2.id])
    end

    test "deleting it soft-deletes its acknowledgements", %{jee: jee, s1: s1, s2: s2} do
      {:ok, _} = StudentExamRecords.delete_student_exam_record(jee)

      for doc <- [s1, s2] do
        stored = Repo.get!(LmsStudentDocument, doc.id)
        assert stored.deleted_at
        assert stored.student_exam_record_id == nil
      end
    end

    test "an acknowledgement that lost its registration can still be soft-deleted", %{s1: s1} do
      Repo.update_all(
        from(d in LmsStudentDocument, where: d.id == ^s1.id),
        set: [student_exam_record_id: nil]
      )

      unlinked = Repo.get!(LmsStudentDocument, s1.id)
      assert {:ok, deleted} = LmsStudentDocuments.soft_delete_lms_student_document(unlinked)
      assert deleted.deleted_at
    end
  end
end
