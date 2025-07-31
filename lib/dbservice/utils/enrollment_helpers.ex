defmodule Dbservice.DataImport.EnrollmentHelpers do
  @moduledoc """
  Helper functions for enrollment operations used by both StudentEnrollment and TeacherEnrollment modules.
  Contains common patterns for creating enrollment records across different group types.
  """

  alias Dbservice.Services.EnrollmentService
  alias Dbservice.Grades

  @doc """
  Creates auth group enrollment for a user.
  """
  def create_auth_group_enrollment(user_id, %{"auth_group" => auth_group_name} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "auth_group",
      "auth_group" => auth_group_name,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  def create_auth_group_enrollment(_, _params), do: {:ok, "No auth-group enrollment needed"}

  @doc """
  Creates batch enrollment for a user.
  """
  def create_batch_enrollment(user_id, %{"batch_id" => batch_id} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "batch",
      "batch_id" => batch_id,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  def create_batch_enrollment(_, _params), do: {:ok, "No batch enrollment needed"}

  @doc """
  Creates grade enrollment for a user using grade_id.
  """
  def create_grade_enrollment(user_id, %{"grade_id" => grade_id} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "grade",
      "grade_id" => grade_id,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  @doc """
  Creates grade enrollment for a user using grade number (for teacher enrollment).
  """
  def create_grade_enrollment(user_id, %{"grade" => grade_number} = params) do
    with {:ok, %Grades.Grade{id: grade_id}} <-
           Grades.get_grade_by_number(grade_number, params["academic_year"]) do
      enrollment_data = %{
        "user_id" => user_id,
        "enrollment_type" => "grade",
        "grade_id" => grade_id,
        "academic_year" => params["academic_year"],
        "start_date" => params["start_date"]
      }

      EnrollmentService.process_enrollment(enrollment_data)
    else
      _error -> {:error, "Invalid grade number"}
    end
  end

  def create_grade_enrollment(_, _params), do: {:ok, "No grade enrollment needed"}
end
