defmodule Dbservice.StudentExamRecords do
  @moduledoc """
  The StudentExamRecords context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Exams.StudentExamRecord

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
    student_exam_record
    |> StudentExamRecord.changeset(attrs)
    |> Repo.update()
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
    Repo.delete(student_exam_record)
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
