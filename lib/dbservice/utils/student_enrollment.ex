defmodule Dbservice.DataImport.StudentEnrollment do
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.AuthGroups
  alias Dbservice.Schools
  alias Dbservice.Batches
  alias Dbservice.Grades
  alias Dbservice.EnrollmentRecords
  alias Dbservice.Groups.GroupUser

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

    case AuthGroups.get_auth_group_by_name(auth_group_name) do
      nil ->
        {:error, :auth_group_not_found}
      auth_group ->
        case Groups.get_group_by_child_id_and_type(auth_group.id, "auth_group") do
          nil ->
            {:error, :group_not_found}
          group ->
            create_or_update_enrollment(user_id, group, params)
        end
    end
  end

  defp create_auth_group_enrollment(_, _params), do: {:ok, "No auth-group enrollment needed"}

  defp create_school_enrollment(user_id, %{"school_code" => school_code} = params) do
    case Schools.get_school_by_code(school_code) do
      nil ->
        {:error, :school_not_found}
      school ->
        case Groups.get_group_by_child_id_and_type(school.id, "school") do
          nil ->
            {:error, :group_not_found}
          group ->
            create_or_update_enrollment(user_id, group, params)
        end
    end
  end

  defp create_school_enrollment(_, _params), do: {:ok, "No school enrollment needed"}

  defp create_batch_enrollment(user_id, %{"batch_id" => batch_id} = params) do
    case Batches.get_batch_by_batch_id(batch_id) do
      nil ->
        {:error, :batch_not_found}
      batch ->
        case Groups.get_group_by_child_id_and_type(batch.id, "batch") do
          nil ->
            {:error, :group_not_found}
          group ->
            create_or_update_enrollment(user_id, group, params)
        end
    end
  end

  defp create_batch_enrollment(_, _params), do: {:ok, "No batch enrollment needed"}

  defp create_grade_enrollment(user_id, %{"grade" => grade} = params) do
    case Grades.get_grade_by_number(grade) do
      nil ->
        {:error, :grade_not_found}
      grade_record ->
        case Groups.get_group_by_child_id_and_type(grade_record.id, "grade") do
          nil ->
            {:error, :group_not_found}
          group ->
            create_or_update_enrollment(user_id, group, params)
        end
    end
  end

  defp create_grade_enrollment(_, _params), do: {:ok, "No grade enrollment needed"}

  defp create_or_update_enrollment(user_id, group, params) do
    group_user_params = %{
      "user_id" => user_id,
      "group_id" => group.id,
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    case GroupUsers.get_group_user_by_user_id_and_group_id(user_id, group.id) do
      nil ->
        create_new_group_user(group, group_user_params)
      existing_group_user ->
        update_existing_group_user(existing_group_user, group_user_params)
    end
  end

  defp create_new_group_user(group, params) do
    academic_year = resolve_academic_year(group.type, params)

    enrollment_record = %{
      "group_id" => group.child_id,
      "group_type" => group.type,
      "user_id" => params["user_id"],
      "academic_year" => academic_year,
      "start_date" => params["start_date"]
    }

    with {:ok, %EnrollmentRecords.EnrollmentRecord{} = _} <-
           EnrollmentRecords.create_enrollment_record(enrollment_record),
         {:ok, %GroupUser{} = group_user} <- GroupUsers.create_group_user(params) do
      {:ok, group_user}
    end
  end

  defp update_existing_group_user(existing_group_user, params) do
    case GroupUsers.update_group_user(existing_group_user, params) do
      {:ok, group_user} -> {:ok, group_user}
      error -> error
    end
  end

  defp resolve_academic_year(group_type, params) do
    if group_type == "auth_group" do
      nil
    else
      params["academic_year"]
    end
  end
end
