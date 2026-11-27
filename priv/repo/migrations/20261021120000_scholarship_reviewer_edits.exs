defmodule Dbservice.Repo.Migrations.ScholarshipReviewerEdits do
  use Ecto.Migration

  # af-scholarship — let a reviewer correct the fee structure herself, and keep
  # what was there before. The Program Team's ask (Sanghamitra, 21 Oct 2026):
  # in Reviewer Portal -> Application Review -> College & Bank, a reviewer can
  # edit the fee details and replace the fee-structure document, and "old data
  # and documents should be saved in the system as history, so we can view them
  # later if needed".
  #
  # Until now the only way to change a submitted answer was to flag the block and
  # wait for the student to resubmit, and both paths OVERWRITE: a stage save
  # replaces the whole stage3_data blob, and a re-upload deletes the previous
  # page rows AND their S3 objects (documents-store.uploadDocument). So the
  # history has to be written at the moment of the edit — there is nothing to
  # reconstruct it from afterwards, and nothing to backfill here.
  #
  # ONE table, not two. A field edit and a document replacement are the same
  # event seen twice — who changed what, on which card, when — and the only
  # difference is what the before/after hold: the block's field values for a
  # field edit, the document's page rows (s3_key, mime_type, byte_size,
  # page_number) for a replacement. Both are shapes the app already has as JSON,
  # so they ride in two jsonb columns and the reviewer's history view reads one
  # ordered list rather than merging two.
  #
  # `document_block` is the reviewer's own flaggable unit (review-flags.ts), the
  # same vocabulary `scholarship_review_flags.document_block` uses — so history
  # and flags line up on one card, and extending this to another block later is
  # a UI change with no DDL. Only "fee_structure" is editable today.
  #
  # An s3_key named in `before_data` must stay readable, so the reviewer-replace
  # path keeps the superseded objects instead of deleting them. That is the one
  # behaviour change on the app side, and it is why this record is the only copy
  # of where those files are.
  #
  # Additive -> deploy-safe, no backfill. The app tolerates the table's absence
  # only in that nothing reads it before the feature ships; apply this BEFORE
  # the app deploy (the responded_at lesson, 7 Aug 2026).
  def up do
    create table(:scholarship_application_edits) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      # The reviewer card the edit was made on — "fee_structure" today.
      add :document_block, :string, null: false

      # fields | document
      add :kind, :string, null: false

      add :editor_id, references(:scholarship_reviewers, on_delete: :nilify_all)

      # kind = "fields":   %{"fee_rows" => [...]} as the block held it / now holds it.
      # kind = "document": %{"doc_type" => "fee_structure", "pages" => [%{"s3_key" => ...}]}
      #                    — the replaced upload's page rows, which is the ONLY
      #                    record of those objects once the new upload lands.
      add :before_data, :map, null: false, default: %{}
      add :after_data, :map, null: false, default: %{}

      # Why she changed it. Optional: a correction obvious from the before/after
      # should not be gated on prose, and an empty note must not cost the record.
      add :notes, :text

      timestamps(updated_at: false)
    end

    # The history view asks one question: everything for this application, newest
    # first. Block filtering happens within that handful of rows.
    create index(:scholarship_application_edits, [:application_id])
  end

  def down do
    drop table(:scholarship_application_edits)
  end
end
