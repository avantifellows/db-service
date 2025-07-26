defmodule Dbservice.DataImport.StudentEnrollment do
  @moduledoc """
  This module handles the student enrollment process by assigning users to different
  groups such as auth groups, schools, batches, and grades.

  The `create_enrollments/2` function ensures that a user is enrolled in all
  applicable groups by delegating to the shared enrollment service.
  """

  alias Dbservice.Services.EnrollmentService

  def create_enrollments(user, params) do
    user_id = user.id

    with {:ok, _auth_enrollment} <- create_auth_group_enrollment(user_id, params),
         {:ok, _school_enrollment} <- create_school_enrollment(user_id, params),
         {:ok, _batch_enrollment} <- create_batch_enrollment(user_id, params),
         {:ok, _grade_enrollment} <- create_grade_enrollment(user_id, params) do
      {:ok, "Enrollments created successfully"}
    else
      error -> error
    end
  end

  defp create_auth_group_enrollment(user_id, %{"auth_group" => auth_group_name} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "auth_group",
      "auth_group" => auth_group_name,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  defp create_auth_group_enrollment(_, _params), do: {:ok, "No auth-group enrollment needed"}

  defp create_school_enrollment(user_id, %{"school_code" => school_code} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "school",
      "school_code" => school_code,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  defp create_school_enrollment(_, _params), do: {:ok, "No school enrollment needed"}

  defp create_batch_enrollment(user_id, %{"batch_id" => batch_id} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "batch",
      "batch_id" => batch_id,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  defp create_batch_enrollment(_, _params), do: {:ok, "No batch enrollment needed"}

  defp create_grade_enrollment(user_id, %{"grade_id" => grade_id} = params) do
    enrollment_data = %{
      "user_id" => user_id,
      "enrollment_type" => "grade",
      "grade_id" => grade_id,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  defp create_grade_enrollment(_, _params), do: {:ok, "No grade enrollment needed"}
end
