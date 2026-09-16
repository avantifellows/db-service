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
  Retrieves the current grade ID for a given user.

  The function fetches the most recent enrollment record where:
  - The user is currently enrolled (`is_current == true`)
  - The enrollment is of type "grade"
  - Results are ordered by `inserted_at` in descending order to get the latest entry.

  Returns `nil` if no enrollment record is found.

  ## Examples

      iex> get_current_grade_id(123)
      9

      iex> get_current_grade_id(456)
      nil

  """
  def get_current_grade_id(user_id) do
    current_enrollment =
      from(e in EnrollmentRecord,
        where: e.user_id == ^user_id and e.is_current == true and e.group_type == "grade",
        order_by: [desc: e.inserted_at],
        limit: 1
      )
      |> Repo.one()

    case current_enrollment do
      nil -> nil
      enrollment -> enrollment.group_id
    end
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
  Creates a status history row inside an existing transaction.
  The caller must own a newly inserted Student or hold the Student row lock.
  """
  def create_status_enrollment(user_id, title, start_date, academic_year, operation_time) do
    statuses =
      from(s in Dbservice.Statuses.Status,
        where: fragment("?::text = ?", s.title, ^title),
        limit: 2
      )
      |> Repo.all()

    current_status? =
      Repo.exists?(
        from(e in EnrollmentRecord,
          where: e.user_id == ^user_id and e.group_type == "status" and e.is_current == true
        )
      )

    cond do
      statuses == [] ->
        {:error, "The Student status is not configured"}

      length(statuses) > 1 ->
        {:error, "Multiple Student statuses are configured with the same title"}

      current_status? ->
        {:error, "Student already has a current status enrollment"}

      true ->
        [status] = statuses

        %EnrollmentRecord{inserted_at: operation_time, updated_at: operation_time}
        |> EnrollmentRecord.changeset(%{
          user_id: user_id,
          group_id: status.id,
          group_type: "status",
          start_date: start_date,
          academic_year: academic_year,
          is_current: true
        })
        |> Repo.insert()
    end
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

  @doc """
  Deletes all enrollment records for a given user.

  Returns {:ok, count} where `count` is the number of rows deleted.
  Note: `count` is currently unused by callers but can be useful for
  logging/metrics or conditional logic.
  """
  def delete_all_by_user_id(user_id) do
    {count, _} =
      from(er in EnrollmentRecord, where: er.user_id == ^user_id) |> Repo.delete_all()

    {:ok, count}
  end

  @doc """
  Deletes enrollment records for a given user limited to a specific batch.
  Returns {:ok, count} where `count` is the number of rows deleted.
  Note: `count` is currently unused by callers but can be useful for
  logging/metrics or conditional logic.
  """
  def delete_batch_enrollments(user_id, batch_id) do
    {count, _} =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_type == "batch" and
            er.group_id == ^batch_id
      )
      |> Repo.delete_all()

    {:ok, count}
  end
end
