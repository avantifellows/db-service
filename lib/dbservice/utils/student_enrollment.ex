defmodule Dbservice.DataImport.StudentEnrollment do
  @moduledoc """
  This module handles the student enrollment process by assigning users to different
  groups such as auth groups, schools, batches, and grades.

  The `create_enrollments/2` function ensures that a user is enrolled in all
  applicable groups by delegating to the shared enrollment service.
  """

  alias Dbservice.Services.EnrollmentService
  alias Dbservice.DataImport.EnrollmentHelpers

  def create_enrollments(user, params) do
    user_id = user.id

    with {:ok, _auth_enrollment} <-
           EnrollmentHelpers.create_auth_group_enrollment(user_id, params),
         {:ok, _school_enrollment} <- create_school_enrollment(user_id, params),
         {:ok, _batch_enrollment} <- EnrollmentHelpers.create_batch_enrollment(user_id, params),
         {:ok, _grade_enrollment} <- EnrollmentHelpers.create_grade_enrollment(user_id, params) do
      {:ok, "Enrollments created successfully"}
    else
      error -> error
    end
  end

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
end
