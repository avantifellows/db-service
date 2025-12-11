defmodule Dbservice.Services.GroupUpdateService do
  @moduledoc """
  Service module for handling group user updates and enrollment record management.
  This module contains shared logic used by both GroupUserController and GroupUpdateProcessor.
  """

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Users

  @doc """
  Updates a user's group membership by type.
  This is the core logic extracted from GroupUserController.update_by_type.

  ## Parameters
  - `params`: Map containing "user_id", "group_id", "type", and optionally "current_batch_pk"

  ## Returns
  - `{:ok, updated_group_user}` on success
  - `{:error, reason}` on failure
  """
  def update_user_group_by_type(params) do
    user_id = params["user_id"]

    with {:ok, type} <- fetch_type(params),
         {:ok, new_group} <- fetch_group(params["group_id"], type),
         group_users <- GroupUsers.get_group_user_by_user_id_and_type(user_id, type),
         {group_user_to_update, enrollment_record} <-
           find_records_to_update(group_users, user_id, type, params),
         {:ok, {group_user, enrollment_record}} <-
           ensure_records(group_user_to_update, enrollment_record),
         {:ok, updated_group_user} <-
           update_group_user_and_enrollment(
             group_user,
             enrollment_record,
             params,
             new_group.child_id
           ),
         :ok <- maybe_update_student_grade(user_id, type, new_group.child_id) do
      {:ok, updated_group_user}
    end
  end

  defp fetch_type(params) do
    type = params["type"] || params["group_type"]

    if is_nil(type) or type == "" do
      {:error, "group type is required"}
    else
      {:ok, type}
    end
  end

  defp fetch_group(group_id, type) do
    case Groups.get_group_by_group_id_and_type(group_id, type) do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  defp ensure_records(nil, _), do: {:error, :not_found}
  defp ensure_records(_, nil), do: {:error, :not_found}
  defp ensure_records(group_user, enrollment_record), do: {:ok, {group_user, enrollment_record}}

  @doc """
  Finds the records to update based on the group type and parameters.
  """
  def find_records_to_update(group_users, user_id, type, params) do
    group_user_to_update = find_group_user_to_update(group_users, type, params)
    enrollment_record = find_enrollment_record(user_id, type, params)

    {group_user_to_update, enrollment_record}
  end

  @doc """
  Finds the specific group user to update based on type and parameters.
  """
  def find_group_user_to_update(group_users, "batch", %{"current_batch_pk" => current_batch_pk}) do
    Enum.find(group_users, fn gu -> gu.group.child_id == current_batch_pk end)
  end

  def find_group_user_to_update(group_users, _type, _params) do
    List.first(group_users)
  end

  @doc """
  Finds the enrollment record to update based on type and parameters.
  """
  def find_enrollment_record(user_id, "batch", %{"current_batch_pk" => current_batch_pk}) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_type == "batch" and
          er.group_id == ^current_batch_pk and
          er.is_current == true
    )
    |> Repo.one()
  end

  def find_enrollment_record(user_id, type, _params) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_type == ^type and
          er.is_current == true
    )
    |> Repo.one()
  end

  @doc """
  Updates both the group user and enrollment record in a transaction.
  """
  def update_group_user_and_enrollment(group_user, enrollment_record, params, new_group_id) do
    Repo.transaction(fn ->
      with {:ok, updated_group_user} <-
             GroupUsers.update_group_user(group_user, %{group_id: params["group_id"]}),
           {:ok, _updated_enrollment_record} <-
             EnrollmentRecords.update_enrollment_record(enrollment_record, %{
               "group_id" => new_group_id
             }) do
        updated_group_user
      else
        {:error, failed_operation} ->
          Repo.rollback(failed_operation)
      end
    end)
  end

  defp maybe_update_student_grade(_user_id, type, _new_group_child_id) when type != "grade",
    do: :ok

  defp maybe_update_student_grade(user_id, "grade", new_group_child_id) do
    case Users.get_student_by_user_id(user_id) do
      nil ->
        :ok

      student ->
        case Users.update_student(student, %{"grade_id" => new_group_child_id}) do
          {:ok, _} -> :ok
          {:error, _changeset} -> {:error, "Failed to update student grade"}
        end
    end
  end
end
