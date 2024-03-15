defmodule Dbservice.EnrollmentRecords do
  @moduledoc """
  The EnrollmentRecords context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  @doc """
  Returns the list of enrollment_record.

  ## Examples

      iex> list_enrollment_record()
      [%EnrollmentRecord{}, ...]

  """
  def list_enrollment_record do
    Repo.all(EnrollmentRecord)
  end

  @doc """
  Gets a single enrollment_record.

  Raises `Ecto.NoResultsError` if the Enrollment record does not exist.

  ## Examples

      iex> get_enrollment_record!(123)
      %EnrollmentRecord{}

      iex> get_enrollment_record!(456)
      ** (Ecto.NoResultsError)

  """
  def get_enrollment_record!(id), do: Repo.get!(EnrollmentRecord, id)

  @doc """
  Gets enrollment_record based on certain parameters.

  Raises `Ecto.NoResultsError` if the Enrollment record does not exist.

  ## Examples

      iex> get_enrollment_record_by_params!(123, 1, "batch", 9, 2023-2024)
      %EnrollmentRecord{}

      iex> get_enrollment_record_by_params!(456, 1, "program", 9, 2023-2024)
      ** (Ecto.NoResultsError)

  """
  def get_enrollment_record_by_params(
        student_id,
        grouping_id,
        grouping_type,
        grade,
        academic_year
      ) do
    Repo.get_by(EnrollmentRecord,
      student_id: student_id,
      grouping_id: grouping_id,
      grouping_type: grouping_type,
      grade: grade,
      academic_year: academic_year
    )
  end

  @doc """
  Creates a enrollment_record.

  ## Examples

      iex> create_enrollment_record(%{field: value})
      {:ok, %EnrollmentRecord{}}

      iex> create_enrollment_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_enrollment_record(attrs \\ %{}) do
    %EnrollmentRecord{}
    |> EnrollmentRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a enrollment_record.

  ## Examples

      iex> update_enrollment_record(enrollment_record, %{field: new_value})
      {:ok, %EnrollmentRecord{}}

      iex> update_enrollment_record(enrollment_record, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_enrollment_record(%EnrollmentRecord{} = enrollment_record, attrs) do
    enrollment_record
    |> EnrollmentRecord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a enrollment_record.

  ## Examples

      iex> delete_enrollment_record(enrollment_record)
      {:ok, %EnrollmentRecord{}}

      iex> delete_enrollment_record(enrollment_record)
      {:error, %Ecto.Changeset{}}

  """
  def delete_enrollment_record(%EnrollmentRecord{} = enrollment_record) do
    Repo.delete(enrollment_record)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking enrollment_record changes.

  ## Examples

      iex> change_enrollment_record(enrollment_record)
      %Ecto.Changeset{data: %EnrollmentRecord{}}

  """
  def change_enrollment_record(%EnrollmentRecord{} = enrollment_record, attrs \\ %{}) do
    EnrollmentRecord.changeset(enrollment_record, attrs)
  end
end
