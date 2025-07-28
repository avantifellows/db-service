defmodule Dbservice.Services.StudentUpdateService do
  @moduledoc """
  Service for handling student updates with user data.
  This service provides reusable functionality for updating students and their associated user records,
  whether from API endpoints or CSV imports.
  """

  alias Dbservice.Users

  @doc """
  Updates a student and their associated user data.
  Only updates fields that are provided in the params (non-nil values).

  ## Parameters
  - student_id: The student ID to find and update
  - params: Map containing the fields to update

  ## Returns
  - {:ok, student} if successful
  - {:error, reason} if student not found or update fails
  """
  def update_student_by_student_id(student_id, params) do
    case Users.get_student_by_student_id(student_id) do
      nil ->
        {:error, "Student not found with ID: #{student_id}"}

      student ->
        update_student_with_user_data(student, params)
    end
  end

  @doc """
  Updates a student and their associated user data.
  Only updates fields that are provided in the params (non-nil values).

  ## Parameters
  - student: The student struct to update
  - params: Map containing the fields to update

  ## Returns
  - {:ok, student} if successful
  - {:error, changeset} if update fails
  """
  def update_student_with_user_data(student, params) do
    user = Users.get_user!(student.user_id)

    # Filter out nil/empty values to only update provided fields
    filtered_params = filter_update_params(params)

    Users.update_student_with_user(student, user, filtered_params)
  end

  # Private helper functions

  defp filter_update_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Enum.into(%{})
  end
end
