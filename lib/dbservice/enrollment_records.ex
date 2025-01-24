defmodule Dbservice.EnrollmentRecords do
  @moduledoc """
  The EnrollmentRecords context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
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
  Gets a Enrollment Records by user ID.
  Raises `Ecto.NoResultsError` if the Enrollment Records does not exist.
  ## Examples
      iex> get_enrollment_records_by_user_id(1234)
      %Batch{}
      iex> get_enrollment_records_by_user_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_enrollment_records_by_user_id(user_id) do
    Repo.all(from e in EnrollmentRecord, where: e.user_id == ^user_id)
  end

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
        user_id,
        group_id,
        group_type,
        academic_year
      ) do
    Repo.get_by(EnrollmentRecord,
      user_id: user_id,
      group_id: group_id,
      group_type: group_type,
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

  @doc """
  Gets a list of Enrollment Record based on the given parameters.
  Returns empty list - [] if no Enrollment record with the given parameters is found.
  """

  def get_enrollment_record_by_params(params) when is_map(params) do
    query = from er in EnrollmentRecord, where: ^Util.build_conditions(params), select: er

    Repo.all(query)
  end

  @doc """
  Fetches all enrollment records for a given user in a specific academic year.
  """
  def get_enrollment_records_by_user_and_academic_year(user_id, academic_year) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.academic_year == ^academic_year
    )
    |> Repo.all()
  end
end
