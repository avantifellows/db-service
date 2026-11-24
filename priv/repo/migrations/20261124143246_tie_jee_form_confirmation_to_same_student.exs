defmodule Dbservice.Repo.Migrations.TieJeeFormConfirmationToSameStudent do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes these tables
  # directly over SQL, so there is no schema/context/controller here.
  #
  # Why: a filled JEE form update can point at its confirmation page, an
  # lms_student_documents row. Until now the database only checked that the document
  # existed, not that it belonged to the same Student, so a bug in af_lms could attach one
  # Student's confirmation to another Student's JEE form. Now the database refuses that:
  # (confirmation_document_id, student_id) must name a document of the same Student, the
  # way Mentor Flags and Action Items already point at a JEE form update.
  #
  # - lms_student_documents gets a unique (id, student_id) index for the FK to point at
  #   (id alone is already unique, so this can't fail on existing rows).
  # - The single-column FK on confirmation_document_id is replaced by the composite one,
  #   under the same name. The column stays nullable; a NULL document isn't checked.
  #
  # Rolling back restores the single-column FK, then drops the index.

  @updates :blended_learning_jee_form_updates
  @documents :lms_student_documents

  def change do
    create unique_index(@documents, [:id, :student_id],
             name: :lms_student_documents_id_student_unique
           )

    alter table(@updates) do
      modify :confirmation_document_id,
             references(@documents, with: [student_id: :student_id], on_delete: :nothing),
             from: references(@documents, on_delete: :nothing)
    end
  end
end
