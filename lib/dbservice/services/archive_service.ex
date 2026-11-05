defmodule Dbservice.Services.ArchiveService do
  @moduledoc """
  Shared service for archiving a student.

  Archiving does the same thing to a student's enrollments as a dropout does —
  every current enrollment is ended and a status enrollment record is written —
  but the status recorded on the student and on that enrollment record is
  `archived` instead of `dropout`. It is used by the Student Archive import.

  The enrollment teardown itself is `DropoutService.update_current_enrollments/3`,
  so the two flows cannot drift on how enrollments are ended or on the
  `updated_at` maintenance that repair runbooks depend on.
  """

  import Ecto.Query

  alias Dbservice.EnrollmentRecords
  alias Dbservice.Groups.Group
  alias Dbservice.Repo
  alias Dbservice.Services.DropoutService
  alias Dbservice.Statuses.Status
  alias Dbservice.Users
  alias Dbservice.Users.Student

  @archived_status "archived"

  @doc """
  Fetches archived status information.
  Returns {status_id, status_group_type} or nil when the status is not seeded.
  """
  def get_archived_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :archived,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Archives a student: ends every current enrollment, writes an `archived`
  status enrollment record and sets the student's status to `archived`.

  Returns {:ok, student} on success or {:error, reason} on failure.
  """
  def process_archive(student, start_date, academic_year) do
    Repo.transaction(fn ->
      with {:ok, student} <- lock_student(student.id),
           :ok <- validate_archive_status(student),
           operation_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
           {:ok, updated_student} <-
             create_archive_enrollment(student, start_date, academic_year, operation_time) do
        updated_student
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp lock_student(student_id) do
    case from(s in Student, where: s.id == ^student_id, lock: "FOR UPDATE") |> Repo.one() do
      nil -> {:error, "Student not found"}
      student -> {:ok, student}
    end
  end

  defp validate_archive_status(%{status: @archived_status}),
    do: {:error, "Student is already marked as archived"}

  defp validate_archive_status(_student), do: :ok

  defp create_archive_enrollment(student, start_date, academic_year, operation_time) do
    case get_archived_status_info() do
      nil ->
        {:error, "Archived status not found in the system"}

      {status_id, group_type} ->
        DropoutService.update_current_enrollments(student.user_id, start_date, operation_time)

        new_enrollment_attrs =
          build_enrollment_attrs(student, status_id, group_type, start_date, academic_year)

        with {:ok, _enrollment_record} <-
               EnrollmentRecords.create_enrollment_record(new_enrollment_attrs),
             {:ok, updated_student} <-
               Users.update_student(student, %{"status" => @archived_status}) do
          {:ok, updated_student}
        else
          {:error, changeset} -> {:error, format_archive_error(changeset)}
        end
    end
  end

  defp build_enrollment_attrs(student, status_id, group_type, start_date, academic_year) do
    %{
      user_id: student.user_id,
      is_current: true,
      start_date: start_date,
      group_id: status_id,
      group_type: group_type,
      academic_year: academic_year,
      grade_id: student.grade_id
    }
  end

  defp format_archive_error(%Ecto.Changeset{} = changeset) do
    if changeset.errors != [] do
      "Failed to archive student: #{inspect(changeset.errors)}"
    else
      "Failed to archive student"
    end
  end

  defp format_archive_error(reason) when is_binary(reason), do: reason
  defp format_archive_error(reason), do: "Failed to archive student: #{inspect(reason)}"
end
