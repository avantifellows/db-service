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
    type = params["type"]

    case Groups.get_group_by_group_id_and_type(params["group_id"], type) do
      nil ->
        {:error, :not_found}

      new_group ->
        new_group_id = new_group.child_id

        # Fetch all GroupUsers for the specified user_id and type
        group_users = GroupUsers.get_group_user_by_user_id_and_type(user_id, type)

        # Determine which GroupUser to update and fetch the corresponding EnrollmentRecord
        {group_user_to_update, enrollment_record} =
          find_records_to_update(group_users, user_id, type, params)

        case {group_user_to_update, enrollment_record} do
          {nil, _} ->
            {:error, :not_found}

          {_, nil} ->
            {:error, :not_found}

          {group_user, enrollment_record} ->
            update_group_user_and_enrollment(
              group_user,
              enrollment_record,
              params,
              new_group_id
            )
        end
    end
  end

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
end
