defmodule Dbservice.Repo.Migrations.CreateLmsStudentDocumentsTable do
  use Ecto.Migration

  def change do
    create table(:lms_student_documents) do
      add :student_id, references(:student, on_delete: :nothing), null: false

      # Document identification (allowlist validated in app, not DB)
      add :document_type, :string, size: 50, null: false

      # Multi-page payload: [{s3_key, page_number, mime_type, byte_size}]
      add :pages, :map, default: fragment("'[]'::jsonb"), null: false

      # Extensible per-type fields
      add :metadata, :map, default: %{}, null: false

      # Email of the user who uploaded
      add :uploaded_by, :string, size: 255, null: false

      # Soft delete
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("(NOW() AT TIME ZONE 'UTC')"), null: false)
    end

    create index(:lms_student_documents, [:student_id])
    create index(:lms_student_documents, [:document_type])
    create index(:lms_student_documents, [:student_id, :document_type])

    create index(:lms_student_documents, [:student_id, :document_type],
             where: "deleted_at IS NULL",
             name: :lms_student_documents_active_idx
           )
  end
end
