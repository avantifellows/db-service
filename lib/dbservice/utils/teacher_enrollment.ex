defmodule Dbservice.DataImport.TeacherEnrollment do
  @moduledoc """
  This module handles the teacher enrollment process by assigning users to different
  groups such as auth groups, batches, and grades.

  The `create_enrollments/2` function ensures that a user is enrolled in all
  applicable groups by delegating to the shared enrollment service.
  """

  alias Dbservice.Subjects
  alias Dbservice.DataImport.EnrollmentHelpers

  def create_enrollments(user, params) do
    user_id = user.id

    with {:ok, _auth_enrollment} <-
           EnrollmentHelpers.create_auth_group_enrollment(user_id, params),
         {:ok, _batch_enrollment} <- EnrollmentHelpers.create_batch_enrollment(user_id, params),
         {:ok, _grade_enrollment} <- EnrollmentHelpers.create_grade_enrollment(user_id, params) do
      {:ok, "Enrollments created successfully"}
    else
      error -> error
    end
  end

  @doc """
  Processes subject lookup by name and returns the subject_id.
  This is used during teacher import to convert subject name to subject_id.
  """
  def get_subject_id_by_name(subject_name) when is_binary(subject_name) do
    case Subjects.get_subject_by_name(subject_name) do
      nil -> nil
      subject -> subject.id
    end
  end

  def get_subject_id_by_name(_), do: nil
end
