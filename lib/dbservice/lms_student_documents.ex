defmodule Dbservice.LmsStudentDocuments do
  @moduledoc """
  The LmsStudentDocuments context.

  Stores documents (e.g. research consent forms, ID proofs) tagged to a student,
  with files held in S3 and metadata + page references stored here as JSONB.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

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
    Enum.reduce(params, query, fn
      {"student_id", value}, acc -> where(acc, [d], d.student_id == ^value)
      {:student_id, value}, acc -> where(acc, [d], d.student_id == ^value)
      {"document_type", value}, acc -> where(acc, [d], d.document_type == ^value)
      {:document_type, value}, acc -> where(acc, [d], d.document_type == ^value)
      _, acc -> acc
    end)
  end

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
    %LmsStudentDocument{}
    |> LmsStudentDocument.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Soft-deletes a document by setting deleted_at.
  """
  def soft_delete_lms_student_document(%LmsStudentDocument{} = doc) do
    doc
    |> LmsStudentDocument.changeset(%{
      deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document changes.
  """
  def change_lms_student_document(%LmsStudentDocument{} = doc, attrs \\ %{}) do
    LmsStudentDocument.changeset(doc, attrs)
  end
end
