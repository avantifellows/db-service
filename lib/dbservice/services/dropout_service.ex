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
  def process_dropout(student, start_date, academic_year, audit_params \\ %{}) do
    # Check if the student's status is already 'dropout'
    if student.status == "dropout" do
      {:error, "Student is already marked as dropout"}
    else
      Repo.transaction(fn ->
        with {:ok, updated_student} <-
               create_dropout_enrollment(student, start_date, academic_year),
             {:ok, _audit} <-
               maybe_insert_lms_audit(
                 student,
                 updated_student,
                 start_date,
                 academic_year,
                 audit_params
               ) do
          updated_student
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> case do
        {:ok, updated_student} -> {:ok, updated_student}
        {:error, reason} -> {:error, reason}
      end
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
