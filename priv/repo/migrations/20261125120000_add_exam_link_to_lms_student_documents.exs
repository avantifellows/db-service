defmodule Dbservice.Repo.Migrations.AddExamLinkToLmsStudentDocuments do
  use Ecto.Migration

  def up do
    # An exam acknowledgement (the confirmation page an exam portal
    # issues once a form is submitted) belongs to one exam registration, and for
    # an exam that runs in sessions - JEE Main's Session 1 and Session 2 - to
    # one sitting of it. A document is otherwise only tied to a student, so the
    # registration and the sitting are recorded here.
    #
    # Both columns are nullable with no default, so adding them is
    # metadata-only and does not scan the table. Every existing document keeps
    # NULL in both: none of them belongs to an exam.
    #
    # A registration that is deleted leaves its documents unlinked rather than
    # blocking the delete; the DB Service soft-deletes a registration's
    # acknowledgements in the same transaction, so the link is only ever
    # cleared on rows that are already deleted.
    alter table(:lms_student_documents) do
      add :student_exam_record_id, references(:student_exam_record, on_delete: :nilify_all)
      add :exam_session, :integer
    end

    # Same range as student_exam_record.sessions_applied. That a sitting needs
    # its registration is checked by the changeset, not here: deleting a
    # registration clears the link on its (already soft-deleted) documents and
    # leaves their sitting, which a CHECK on both columns would refuse.
    create constraint(:lms_student_documents, :lms_student_documents_exam_session_check,
             check: "exam_session IS NULL OR exam_session BETWEEN 1 AND 4"
           )

    create index(:lms_student_documents, [:student_exam_record_id])

    # One current document per registration and sitting. A registration with
    # no sittings stores exam_session NULL, which a plain unique index would
    # treat as distinct every time, hence the COALESCE.
    create unique_index(
             :lms_student_documents,
             ["student_exam_record_id", "COALESCE(exam_session, 0)"],
             where: "deleted_at IS NULL AND student_exam_record_id IS NOT NULL",
             name: :lms_student_documents_active_exam_slot_index
           )
  end

  def down do
    drop_if_exists index(:lms_student_documents, [],
                     name: :lms_student_documents_active_exam_slot_index
                   )

    drop_if_exists index(:lms_student_documents, [:student_exam_record_id])

    drop_if_exists constraint(
                     :lms_student_documents,
                     :lms_student_documents_exam_session_check
                   )

    alter table(:lms_student_documents) do
      remove :exam_session
      remove :student_exam_record_id
    end
  end
end
