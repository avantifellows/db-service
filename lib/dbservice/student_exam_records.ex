defmodule Dbservice.StudentExamRecords do
  @moduledoc """
  The StudentExamRecords context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Exams.StudentExamRecord
  alias Dbservice.LmsStudentDocuments

  @doc """
  Returns the list of student_exam_records.

  ## Examples

      iex> list_student_exam_record()
      [%StudentExamRecord{}, ...]

  """
  def list_student_exam_record do
    Repo.all(StudentExamRecord)
  end

  @doc """
  Gets a single student_exam_record.

  Raises `Ecto.NoResultsError` if the StudentExamRecord does not exist.

  ## Examples

      iex> get_student_exam_record!(123)
      %StudentExamRecord{}

      iex> get_student_exam_record!(456)
      ** (Ecto.NoResultsError)

  """
  def get_student_exam_record!(id), do: Repo.get!(StudentExamRecord, id)

  @doc """
  Fetches a single `StudentExamRecord` based on the provided `student_id` and `application_number`.

  Returns `nil` if no matching record is found.

  ## Examples

      iex> get_student_exam_records_by_student_id_and_application_number(123, "APP001")
      %StudentExamRecord{}

      iex> get_student_exam_records_by_student_id_and_application_number(123, "APP999")
      nil

  """
  def get_student_exam_records_by_student_id_and_application_number(
        student_id,
        application_number
      ) do
    Repo.get_by(StudentExamRecord, student_id: student_id, application_number: application_number)
  end

  @doc """
  Creates a student_exam_record.

  ## Examples

      iex> create_student_exam_record(%{field: value})
      {:ok, %StudentExamRecord{}}

      iex> create_student_exam_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_student_exam_record(attrs \\ %{}) do
    %StudentExamRecord{}
    |> StudentExamRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a student_exam_record.

  ## Examples

      iex> update_student_exam_record(student_exam_record, %{field: new_value})
      {:ok, %StudentExamRecord{}}

      iex> update_student_exam_record(student_exam_record, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_student_exam_record(%StudentExamRecord{} = student_exam_record, attrs) do
    changeset = StudentExamRecord.changeset(student_exam_record, attrs)

    if retires_documents?(changeset) do
      update_retiring_documents(changeset)
    else
      Repo.update(changeset)
    end
  end

  # A registration's exam acknowledgements describe its exam and its
  # sittings. Moving it to another exam (create upserts on student and
  # application number, so it can) retires all of them; dropping a sitting
  # retires that sitting's. Either happens in the same transaction as the
  # change.
  defp retires_documents?(changeset) do
    Map.has_key?(changeset.changes, :exam_id) or
      Map.has_key?(changeset.changes, :sessions_applied)
  end

  defp update_retiring_documents(changeset) do
    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, record} ->
          retire_documents(changeset, record)
          record

        {:error, failed} ->
          Repo.rollback(failed)
      end
    end)
  end

  defp retire_documents(changeset, record) do
    if Map.has_key?(changeset.changes, :exam_id) do
      LmsStudentDocuments.soft_delete_exam_documents(record.id)
    else
      LmsStudentDocuments.soft_delete_exam_documents_outside_sessions(
        record.id,
        record.sessions_applied
      )
    end
  end

  @doc """
  Deletes a student_exam_record.

  ## Examples

      iex> delete_student_exam_record(student_exam_record)
      {:ok, %StudentExamRecord{}}

      iex> delete_student_exam_record(student_exam_record)
      {:error, %Ecto.Changeset{}}

  """
  def delete_student_exam_record(%StudentExamRecord{} = student_exam_record) do
    # The registration's exam acknowledgements go with it. They are
    # soft-deleted, like every LMS document, so the files stay recoverable;
    # the foreign key then clears their link when the row goes.
    #
    # The row is locked first, as an upload locks it: otherwise an upload
    # committing between the soft-delete and the delete would leave a live
    # acknowledgement whose link the delete then clears.
    Repo.transaction(fn ->
      StudentExamRecord
      |> where([r], r.id == ^student_exam_record.id)
      |> lock("FOR UPDATE")
      |> Repo.one()

      LmsStudentDocuments.soft_delete_exam_documents(student_exam_record.id)

      case Repo.delete(student_exam_record) do
        {:ok, record} -> record
        {:error, failed} -> Repo.rollback(failed)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking student_exam_record changes.

  ## Examples

      iex> change_student_exam_record(student_exam_record)
      %Ecto.Changeset{data: %StudentExamRecord{}}

  """
  def change_student_exam_record(%StudentExamRecord{} = student_exam_record, attrs \\ %{}) do
    StudentExamRecord.changeset(student_exam_record, attrs)
  end
end
