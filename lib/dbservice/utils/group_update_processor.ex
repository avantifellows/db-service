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
    case Users.get_student_by_student_id(record["student_id"]) do
      nil ->
        {:error, "Student not found with ID: #{record["student_id"]}"}

      student ->
        with {:ok, old_batch} <- get_batch_by_id(record["old_batch_id"]),
             {:ok, new_batch_group_id} <- get_batch_group_id(record["batch_id"]) do
          params = %{
            "user_id" => student.user_id,
            "group_id" => new_batch_group_id,
            "type" => "batch",
            "current_batch_pk" => old_batch.id
          }

          case GroupUpdateService.update_user_group_by_type(params) do
            {:ok, _} -> {:ok, "Batch ID update processed successfully"}
            {:error, :not_found} -> {:error, "Group user or enrollment record not found"}
            {:error, reason} -> {:error, "Update failed: #{inspect(reason)}"}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Processes school correction (student_id, school_code)
  """
  def process_school_update(record) do
    case Users.get_student_by_student_id(record["student_id"]) do
      nil ->
        {:error, "Student not found with ID: #{record["student_id"]}"}

      student ->
        with {:ok, school_group_id} <- get_school_group_id(record["school_code"]) do
          params = %{
            "user_id" => student.user_id,
            "group_id" => school_group_id,
            "type" => "school"
          }

          case GroupUpdateService.update_user_group_by_type(params) do
            {:ok, _} -> {:ok, "School update processed successfully"}
            {:error, :not_found} -> {:error, "Group user or enrollment record not found"}
            {:error, reason} -> {:error, "Update failed: #{inspect(reason)}"}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Processes grade correction (student_id, grade)
  """
  def process_grade_update(record) do
    case Users.get_student_by_student_id(record["student_id"]) do
      nil ->
        {:error, "Student not found with ID: #{record["student_id"]}"}

      student ->
        with {:ok, grade_group_id} <- get_grade_group_id(record["grade"]) do
          params = %{
            "user_id" => student.user_id,
            "group_id" => grade_group_id,
            "type" => "grade"
          }

          case GroupUpdateService.update_user_group_by_type(params) do
            {:ok, _} -> {:ok, "Grade update processed successfully"}
            {:error, :not_found} -> {:error, "Group user or enrollment record not found"}
            {:error, reason} -> {:error, "Update failed: #{inspect(reason)}"}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Processes auth group correction (student_id, auth_group_name)
  """
  def process_auth_group_update(record) do
    case Users.get_student_by_student_id(record["student_id"]) do
      nil ->
        {:error, "Student not found with ID: #{record["student_id"]}"}

      student ->
        with {:ok, auth_group_group_id} <- get_auth_group_id(record["auth_group_name"]) do
          params = %{
            "user_id" => student.user_id,
            "group_id" => auth_group_group_id,
            "type" => "auth_group"
          }

          case GroupUpdateService.update_user_group_by_type(params) do
            {:ok, _} -> {:ok, "Auth group update processed successfully"}
            {:error, :not_found} -> {:error, "Group user or enrollment record not found"}
            {:error, reason} -> {:error, "Update failed: #{inspect(reason)}"}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # Private helper functions

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
