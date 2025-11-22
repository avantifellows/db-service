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
  alias Dbservice.Users

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
  def process_dropout(student, start_date, academic_year) do
    user_id = student.user_id

    # Check if the student's status is already 'dropout'
    if student.status == "dropout" do
      {:error, "Student is already marked as dropout"}
    else
      case get_dropout_status_info() do
        nil ->
          {:error, "Dropout status not found in the system"}

        {status_id, group_type} ->
          # Update all current enrollment records
          update_current_enrollments(user_id, start_date)

          # Get grade_id from the student table
          grade_id = student.grade_id

          # Create a new enrollment record with the fetched status_id
          new_enrollment_attrs = %{
            user_id: user_id,
            is_current: true,
            start_date: start_date,
            group_id: status_id,
            group_type: group_type,
            academic_year: academic_year,
            grade_id: grade_id
          }

          with {:ok, _enrollment_record} <-
                 EnrollmentRecords.create_enrollment_record(new_enrollment_attrs),
               {:ok, updated_student} <-
                 Users.update_student(student, %{"status" => "dropout"}) do
            {:ok, updated_student}
          else
            {:error, changeset} ->
              # Return a more descriptive error message
              error_message =
                if changeset.errors != [] do
                  "Failed to process dropout: #{inspect(changeset.errors)}"
                else
                  "Failed to process dropout"
                end

              {:error, error_message}
          end
      end
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
