defmodule Dbservice.LmsStudentDocuments do
  @moduledoc """
  The LmsStudentDocuments context.

  Stores documents (e.g. research consent forms, ID proofs) tagged to a student,
  with files held in S3 and metadata + page references stored here as JSONB.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Exams.StudentExamRecord
  alias Dbservice.LmsStudentDocuments.LmsStudentDocument

  @doc """
  Lists documents, optionally filtered by student_id and/or document_type.
  Excludes soft-deleted rows.
  """
  def list_lms_student_documents(params \\ %{}) do
    LmsStudentDocument
    |> where([d], is_nil(d.deleted_at))
    |> filter_by(params)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
  end

  defp filter_by(query, params) do
    Enum.reduce(params, query, fn {key, value}, acc ->
      case normalize_key(key) do
        :student_id -> where(acc, [d], d.student_id == ^value)
        :document_type -> where(acc, [d], d.document_type == ^value)
        :student_exam_record_id -> where(acc, [d], d.student_exam_record_id == ^value)
        _ -> acc
      end
    end)
  end

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :unknown
  end

  defp normalize_key(key), do: key

  @doc """
  Gets a single document. Returns `nil` if not found or soft-deleted.
  """
  def get_lms_student_document(id) do
    LmsStudentDocument
    |> where([d], d.id == ^id and is_nil(d.deleted_at))
    |> Repo.one()
  end

  @doc """
  Creates a document.
  """
  def create_lms_student_document(attrs \\ %{}) do
    changeset = LmsStudentDocument.changeset(%LmsStudentDocument{}, attrs)
    record_id = Ecto.Changeset.get_field(changeset, :student_exam_record_id)

    cond do
      is_nil(record_id) -> Repo.insert(changeset)
      changeset.valid? -> create_exam_document(changeset, record_id)
      true -> {:error, changeset}
    end
  end

  # An exam acknowledgement replaces whatever document is current
  # for its registration and sitting, in one transaction: the old one is
  # soft-deleted only if the new one is stored. The registration row is locked
  # so two uploads for the same sitting cannot both pass the check and then
  # trip the unique index.
  defp create_exam_document(changeset, record_id) do
    Repo.transaction(fn ->
      record =
        StudentExamRecord
        |> where([r], r.id == ^record_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      changeset = validate_exam_slot(changeset, record)

      if changeset.valid? do
        soft_delete_exam_slot(record_id, Ecto.Changeset.get_field(changeset, :exam_session))

        case Repo.insert(changeset) do
          {:ok, doc} -> doc
          {:error, failed} -> Repo.rollback(failed)
        end
      else
        Repo.rollback(changeset)
      end
    end)
  end

  # The registration must exist and belong to the document's student, and the
  # sitting must be one the student applied for: a registration with sittings
  # takes one of them, a registration without takes none.
  defp validate_exam_slot(changeset, nil) do
    Ecto.Changeset.add_error(changeset, :student_exam_record_id, "does not exist")
  end

  defp validate_exam_slot(changeset, %StudentExamRecord{} = record) do
    student_id = Ecto.Changeset.get_field(changeset, :student_id)
    session = Ecto.Changeset.get_field(changeset, :exam_session)
    sessions = record.sessions_applied || []

    cond do
      record.student_id != student_id ->
        Ecto.Changeset.add_error(
          changeset,
          :student_exam_record_id,
          "belongs to another student"
        )

      sessions == [] and not is_nil(session) ->
        Ecto.Changeset.add_error(
          changeset,
          :exam_session,
          "must be empty: the student applied for no sessions of this exam"
        )

      sessions != [] and session not in sessions ->
        Ecto.Changeset.add_error(
          changeset,
          :exam_session,
          "must be one of the sessions the student applied for"
        )

      true ->
        changeset
    end
  end

  defp soft_delete_exam_slot(record_id, nil) do
    record_id
    |> active_exam_documents()
    |> where([d], is_nil(d.exam_session))
    |> soft_delete_all()
  end

  defp soft_delete_exam_slot(record_id, session) do
    record_id
    |> active_exam_documents()
    |> where([d], d.exam_session == ^session)
    |> soft_delete_all()
  end

  @doc """
  Soft-deletes every current document of an exam registration. Called in the
  same transaction that deletes the registration.
  """
  def soft_delete_exam_documents(record_id) do
    record_id
    |> active_exam_documents()
    |> soft_delete_all()
  end

  @doc """
  Soft-deletes the current documents of an exam registration that no longer
  fit its sittings: with sittings, a document for any other sitting or for
  none; without, a document for any sitting. Called in the same transaction
  that changes `sessions_applied`.
  """
  def soft_delete_exam_documents_outside_sessions(record_id, sessions)
      when sessions in [nil, []] do
    record_id
    |> active_exam_documents()
    |> where([d], not is_nil(d.exam_session))
    |> soft_delete_all()
  end

  def soft_delete_exam_documents_outside_sessions(record_id, sessions) do
    record_id
    |> active_exam_documents()
    |> where([d], is_nil(d.exam_session) or d.exam_session not in ^sessions)
    |> soft_delete_all()
  end

  defp active_exam_documents(record_id) do
    where(
      LmsStudentDocument,
      [d],
      d.student_exam_record_id == ^record_id and is_nil(d.deleted_at)
    )
  end

  defp soft_delete_all(query) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    Repo.update_all(query, set: [deleted_at: now, updated_at: now])
  end

  @doc """
  Soft-deletes a document by setting deleted_at.

  Only `deleted_at` changes, so the full changeset's checks are not re-run:
  removing a document must work even when the row no longer passes them
  (e.g. an exam acknowledgement whose registration has gone).
  """
  def soft_delete_lms_student_document(%LmsStudentDocument{} = doc) do
    doc
    |> Ecto.Changeset.change(
      deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    )
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document changes.
  """
  def change_lms_student_document(%LmsStudentDocument{} = doc, attrs \\ %{}) do
    LmsStudentDocument.changeset(doc, attrs)
  end
end
