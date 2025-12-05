defmodule Dbservice.DataImport.GroupUpdateProcessor do
  @moduledoc """
  This module handles group update processing for importing user group corrections.
  It reuses the GroupUpdateService for consistent group update functionality.
  """

  alias Dbservice.Users
  alias Dbservice.Groups
  alias Dbservice.Schools
  alias Dbservice.Batches
  alias Dbservice.AuthGroups
  alias Dbservice.Services.GroupUpdateService

  @doc """
  Processes batch ID correction (old_batch_id -> new batch_id)
  """
  def process_batch_id_update(record) do
    with {:ok, student} <- get_student(record),
         {:ok, old_batch} <- get_batch_by_id(record["old_batch_id"]),
         {:ok, new_batch_group_id} <- get_batch_group_id(record["batch_id"]) do
      params = %{
        "user_id" => student.user_id,
        "group_id" => new_batch_group_id,
        "type" => "batch",
        "current_batch_pk" => old_batch.id
      }

      process_group_update(params, "Batch ID update")
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Processes school correction (student_id or apaar_id, school_code)
  """
  def process_school_update(record) do
    process_generic_update(
      record,
      fn -> get_school_group_id(record["school_code"]) end,
      "school",
      "School update"
    )
  end

  @doc """
  Processes grade correction (student_id or apaar_id, grade)
  """
  def process_grade_update(record) do
    process_generic_update(
      record,
      fn -> get_grade_group_id(record["grade"]) end,
      "grade",
      "Grade update"
    )
  end

  @doc """
  Processes auth group correction (student_id or apaar_id, auth_group_name)
  """
  def process_auth_group_update(record) do
    process_generic_update(
      record,
      fn -> get_auth_group_id(record["auth_group_name"]) end,
      "auth_group",
      "Auth group update"
    )
  end

  # Private helper functions

  # Generic processor function that handles the common pattern
  defp process_generic_update(record, group_id_getter_fn, type, success_message_prefix) do
    with {:ok, student} <- get_student(record),
         {:ok, group_id} <- group_id_getter_fn.() do
      params = %{
        "user_id" => student.user_id,
        "group_id" => group_id,
        "type" => type
      }

      process_group_update(params, success_message_prefix)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Common group update processing with consistent error handling
  defp process_group_update(params, success_message_prefix) do
    case GroupUpdateService.update_user_group_by_type(params) do
      {:ok, _} -> {:ok, "#{success_message_prefix} processed successfully"}
      {:error, :not_found} -> {:error, "Group user or enrollment record not found"}
      {:error, reason} -> {:error, "Update failed: #{inspect(reason)}"}
    end
  end

  # Common student lookup with consistent error handling
  defp get_student(record) when is_map(record) do
    student_id = record["student_id"]
    apaar_id = record["apaar_id"]

    # Validate that at least one identifier is provided
    if (is_nil(student_id) or student_id == "") and (is_nil(apaar_id) or apaar_id == "") do
      {:error, "Either student_id or apaar_id is required"}
    else
      case Users.get_student_by_id_or_apaar_id(record) do
        nil ->
          {:error,
           "Student not found. student_id: #{inspect(student_id)}, apaar_id: #{inspect(apaar_id)}"}

        student ->
          {:ok, student}
      end
    end
  end

  defp get_batch_by_id(batch_id) do
    case Batches.get_batch_by_batch_id(batch_id) do
      nil -> {:error, "Batch not found with ID: #{batch_id}"}
      batch -> {:ok, batch}
    end
  end

  defp get_batch_group_id(batch_id) do
    case Batches.get_batch_by_batch_id(batch_id) do
      nil ->
        {:error, "Batch not found with ID: #{batch_id}"}

      batch ->
        case Groups.get_group_by_child_id_and_type(batch.id, "batch") do
          nil -> {:error, "Batch group not found"}
          group -> {:ok, group.id}
        end
    end
  end

  defp get_school_group_id(school_code) do
    case Schools.get_school_by_code(school_code) do
      nil ->
        {:error, "School not found with code: #{school_code}"}

      school ->
        case Groups.get_group_by_child_id_and_type(school.id, "school") do
          nil -> {:error, "School group not found"}
          group -> {:ok, group.id}
        end
    end
  end

  defp get_grade_group_id(grade_number) do
    # Assuming you have a way to get grade by number
    # You might need to adjust this based on your Grades module implementation
    case Dbservice.Grades.get_grade_by_number(grade_number) do
      nil ->
        {:error, "Grade not found with number: #{grade_number}"}

      grade ->
        case Groups.get_group_by_child_id_and_type(grade.id, "grade") do
          nil -> {:error, "Grade group not found"}
          group -> {:ok, group.id}
        end
    end
  end

  defp get_auth_group_id(auth_group_name) do
    case AuthGroups.get_auth_group_by_name(auth_group_name) do
      nil ->
        {:error, "Auth group not found with name: #{auth_group_name}"}

      auth_group ->
        case Groups.get_group_by_child_id_and_type(auth_group.id, "auth_group") do
          nil -> {:error, "Auth group not found"}
          group -> {:ok, group.id}
        end
    end
  end
end
