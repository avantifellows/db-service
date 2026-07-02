defmodule Dbservice.Services.DropoutService do
  @moduledoc """
  Shared service for handling student dropout operations.
  This module contains reusable functions for dropout logic
  used in student controller and dropout imports.
  """

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Schools.School
  alias Dbservice.Statuses.Status
  alias Dbservice.Groups.Group
  alias Dbservice.LmsStudentWriteAudit
  alias Dbservice.Users

  @audit_action "student_dropout"

  @doc """
  Fetches dropout status information.
  Returns {status_id, status_group_type}
  """
  def get_dropout_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :dropout,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  @doc """
  Processes student dropout by updating enrollments and student status.
  Returns {:ok, student} on success or {:error, reason} on failure.
  """
  def process_dropout(student, start_date, academic_year, audit_params \\ %{})

  def process_dropout(%{status: "dropout"}, _start_date, _academic_year, _audit_params),
    do: {:error, "Student is already marked as dropout"}

  def process_dropout(student, start_date, academic_year, audit_params) do
    with :ok <- validate_lms_audit_params(student, audit_params) do
      dropout_transaction(student, start_date, academic_year, audit_params)
    end
  end

  defp dropout_transaction(student, start_date, academic_year, audit_params) do
    Repo.transaction(fn ->
      case create_dropout_with_audit(student, start_date, academic_year, audit_params) do
        {:ok, updated_student} -> updated_student
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp create_dropout_with_audit(student, start_date, academic_year, audit_params) do
    with {:ok, updated_student} <- create_dropout_enrollment(student, start_date, academic_year),
         {:ok, _audit} <-
           maybe_insert_lms_audit(
             student,
             updated_student,
             start_date,
             academic_year,
             audit_params
           ) do
      {:ok, updated_student}
    end
  end

  defp create_dropout_enrollment(student, start_date, academic_year) do
    case get_dropout_status_info() do
      nil ->
        {:error, "Dropout status not found in the system"}

      {status_id, group_type} ->
        user_id = student.user_id
        update_current_enrollments(user_id, start_date)

        new_enrollment_attrs =
          build_enrollment_attrs(student, status_id, group_type, start_date, academic_year)

        with {:ok, _enrollment_record} <-
               EnrollmentRecords.create_enrollment_record(new_enrollment_attrs),
             {:ok, updated_student} <-
               Users.update_student(student, %{"status" => "dropout"}) do
          {:ok, updated_student}
        else
          {:error, changeset} ->
            {:error, format_dropout_error(changeset)}
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

  defp maybe_insert_lms_audit(_student, _updated_student, _start_date, _academic_year, params)
       when params == %{},
       do: {:ok, nil}

  defp maybe_insert_lms_audit(_student, _updated_student, _start_date, _academic_year, params)
       when not is_map_key(params, "actor") or not is_map_key(params, "school"),
       do: {:ok, nil}

  defp maybe_insert_lms_audit(student, updated_student, start_date, academic_year, params) do
    %LmsStudentWriteAudit{}
    |> LmsStudentWriteAudit.changeset(%{
      action: @audit_action,
      actor_user_id: get_in(params, ["actor", "user_id"]),
      actor_email: get_in(params, ["actor", "email"]),
      actor_login_type: get_in(params, ["actor", "login_type"]),
      actor_role: get_in(params, ["actor", "role"]),
      school_code: get_in(params, ["school", "code"]),
      school_udise_code: get_in(params, ["school", "udise_code"]),
      program_id: params["program_id"],
      row_counts: %{},
      affected_identifiers: %{
        "student_pk_id" => student.id,
        "user_id" => student.user_id,
        "student_id" => student.student_id,
        "apaar_id" => student.apaar_id
      },
      changed_values: %{
        "status" => %{"old" => student.status, "new" => updated_student.status},
        "dropout_date" => %{"old" => nil, "new" => start_date},
        "academic_year" => %{"old" => nil, "new" => academic_year}
      }
    })
    |> Repo.insert()
  end

  defp validate_lms_audit_params(_student, params) when params == %{}, do: :ok

  defp validate_lms_audit_params(_student, params)
       when not is_map_key(params, "actor") or not is_map_key(params, "school"),
       do: :ok

  defp validate_lms_audit_params(student, %{"actor" => actor, "school" => school})
       when is_map(actor) and is_map(school) do
    case current_school(student.user_id) do
      %{code: code, udise_code: udise_code} ->
        if school["code"] == code and school["udise_code"] == udise_code do
          :ok
        else
          {:error, "Student is not enrolled in this school"}
        end

      _school ->
        {:error, "Student is not enrolled in this school"}
    end
  end

  defp validate_lms_audit_params(_student, _params), do: {:error, "Invalid LMS audit metadata"}

  defp current_school(user_id) do
    from(e in EnrollmentRecord,
      join: s in School,
      on: s.id == e.group_id,
      where: e.user_id == ^user_id and e.group_type == "school" and e.is_current == true,
      select: s,
      limit: 1
    )
    |> Repo.one()
  end

  defp format_dropout_error(changeset) do
    if changeset.errors != [] do
      "Failed to process dropout: #{inspect(changeset.errors)}"
    else
      "Failed to process dropout"
    end
  end

  @doc """
  Updates all current enrollment records for a user to mark them as not current.
  Sets is_current=false and end_date for all current enrollments.
  """
  def update_current_enrollments(user_id, end_date) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.is_current == true,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end
end
