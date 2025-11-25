defmodule Dbservice.Services.ReEnrollmentService do
  @moduledoc """
  Service for handling student re-enrollment after dropout.
  This module contains reusable functions for re-enrollment logic
  used in student controller and re-enrollment imports.
  """

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Statuses.Status
  alias Dbservice.Groups
  alias Dbservice.Groups.Group
  alias Dbservice.Users
  alias Dbservice.Services.EnrollmentService
  alias Dbservice.Services.DropoutService
  alias Dbservice.GroupUsers
  alias Dbservice.Groups.GroupUser
  alias Dbservice.AuthGroups

  @doc """
  Processes student re-enrollment by validating dropout status, auth-group match,
  and creating new enrollment records.
  Returns {:ok, student} on success or {:error, reason} on failure.
  """
  def process_re_enrollment(student, params) do
    with :ok <- validate_dropout_status(student),
         :ok <- validate_auth_group_match(student, params),
         {:ok, _} <- create_re_enrollment_records(student, params) do
      Users.update_student(student, %{"status" => "enrolled"})
    end
  end

  defp validate_dropout_status(student) do
    if student.status == "dropout" do
      :ok
    else
      {:error, "Student is not in dropout status. Current status: #{student.status}"}
    end
  end

  defp validate_auth_group_match(student, params) do
    # Get current auth-group from student's enrollment records
    current_auth_group_id = get_current_auth_group_id(student.user_id)
    incoming_auth_group_name = params["auth_group"]

    if is_nil(current_auth_group_id) or is_nil(incoming_auth_group_name) do
      {:error, "Auth group information is missing"}
    else
      validate_auth_group_ids(current_auth_group_id, incoming_auth_group_name)
    end
  end

  defp validate_auth_group_ids(current_auth_group_id, incoming_auth_group_name) do
    case EnrollmentService.get_auth_group_id(incoming_auth_group_name) do
      {:error, error_msg} ->
        {:error, error_msg}

      incoming_auth_group_id ->
        compare_auth_group_ids(
          current_auth_group_id,
          incoming_auth_group_id,
          incoming_auth_group_name
        )
    end
  end

  defp compare_auth_group_ids(
         current_auth_group_id,
         incoming_auth_group_id,
         incoming_auth_group_name
       ) do
    # Get the child_id (auth_group.id) from the group
    incoming_auth_group = Groups.get_group!(incoming_auth_group_id)
    incoming_auth_group_child_id = incoming_auth_group.child_id

    # Compare child_ids (the actual auth_group.id values)
    if current_auth_group_id == incoming_auth_group_child_id do
      :ok
    else
      # Get current auth group name for better error message
      current_auth_group_name = get_auth_group_name(current_auth_group_id)

      {:error,
       "Auth group mismatch. Current: #{current_auth_group_name}, Incoming: #{incoming_auth_group_name}"}
    end
  end

  defp get_current_auth_group_id(user_id) do
    # Get the most recent auth_group enrollment record (even if is_current is false)
    # This is needed because when a student is marked as dropout, all their
    # enrollment records are marked as is_current = false
    from(er in EnrollmentRecord,
      join: g in Group,
      on: er.group_id == g.child_id and er.group_type == "auth_group",
      where: er.user_id == ^user_id,
      order_by: [desc: er.inserted_at],
      select: g.child_id,
      limit: 1
    )
    |> Repo.one()
  end

  defp get_auth_group_name(auth_group_id) do
    case AuthGroups.get_auth_group!(auth_group_id) do
      %{name: name} -> name
      _ -> "Unknown (ID: #{auth_group_id})"
    end
  rescue
    _ -> "Unknown (ID: #{auth_group_id})"
  end

  defp create_re_enrollment_records(student, params) do
    user_id = student.user_id
    start_date = params["start_date"]
    academic_year = params["academic_year"]

    # Mark dropout enrollment as not current
    mark_dropout_enrollment_inactive(user_id, start_date)

    # Get enrolled status info
    case get_enrolled_status_info() do
      nil ->
        {:error, "Enrolled status not found in the system"}

      {status_id, status_group_type} ->
        # Create enrolled status enrollment
        create_enrolled_status_enrollment(
          user_id,
          status_id,
          status_group_type,
          start_date,
          academic_year
        )

        # Create enrollment records for grade, batch, school, and auth-group
        with {:ok, _} <- create_grade_enrollment(user_id, params, start_date, academic_year),
             {:ok, _} <- create_batch_enrollment(user_id, params, start_date, academic_year),
             {:ok, _} <- create_school_enrollment(user_id, params, start_date, academic_year),
             {:ok, _} <- create_auth_group_enrollment(user_id, params, start_date) do
          {:ok, student}
        end
    end
  end

  defp mark_dropout_enrollment_inactive(user_id, end_date) do
    # Get dropout status ID
    case DropoutService.get_dropout_status_info() do
      nil ->
        :ok

      {dropout_status_id, _} ->
        from(er in EnrollmentRecord,
          where:
            er.user_id == ^user_id and
              er.group_id == ^dropout_status_id and
              er.group_type == "status" and
              er.is_current == true,
          update: [set: [is_current: false, end_date: ^end_date]]
        )
        |> Repo.update_all([])

        :ok
    end
  end

  defp get_enrolled_status_info do
    from(s in Status,
      join: g in Group,
      on: g.child_id == s.id and g.type == "status",
      where: s.title == :enrolled,
      select: {g.child_id, g.type}
    )
    |> Repo.one()
  end

  defp create_enrolled_status_enrollment(
         user_id,
         status_id,
         status_group_type,
         start_date,
         academic_year
       ) do
    enrollment_attrs = %{
      "user_id" => user_id,
      "is_current" => true,
      "start_date" => start_date,
      "group_id" => status_id,
      "group_type" => status_group_type,
      "academic_year" => academic_year
    }

    EnrollmentRecords.create_enrollment_record(enrollment_attrs)
  end

  defp create_grade_enrollment(user_id, params, start_date, academic_year) do
    grade_id = Map.get(params, "grade_id")
    process_grade_enrollment(user_id, grade_id, start_date, academic_year)
  end

  defp process_grade_enrollment(user_id, grade_id, start_date, academic_year) do
    case EnrollmentService.get_grade_group_id(grade_id) do
      {:error, error_msg} ->
        {:error, error_msg}

      group_id ->
        create_grade_enrollment_record(user_id, group_id, start_date, academic_year)
    end
  end

  defp create_grade_enrollment_record(user_id, group_id, start_date, academic_year) do
    group = Groups.get_group!(group_id)

    enrollment_attrs = %{
      "user_id" => user_id,
      "is_current" => true,
      "start_date" => start_date,
      "group_id" => group.child_id,
      "group_type" => "grade",
      "academic_year" => academic_year
    }

    # Update existing grade enrollments to not current
    update_existing_enrollments(user_id, "grade", start_date)

    case EnrollmentRecords.create_enrollment_record(enrollment_attrs) do
      {:ok, _} ->
        # Update or create group-user
        update_or_create_group_user(user_id, group_id)
        {:ok, "Grade enrollment created"}

      error ->
        error
    end
  end

  defp create_batch_enrollment(user_id, params, start_date, academic_year) do
    batch_id = Map.get(params, "batch_id")
    process_batch_enrollment(user_id, batch_id, start_date, academic_year)
  end

  defp process_batch_enrollment(user_id, batch_id, start_date, academic_year) do
    case EnrollmentService.get_batch_group_id(batch_id) do
      {:error, error_msg} ->
        {:error, error_msg}

      group_id ->
        create_batch_enrollment_record(user_id, group_id, start_date, academic_year)
    end
  end

  defp create_batch_enrollment_record(user_id, group_id, start_date, academic_year) do
    group = Groups.get_group!(group_id)

    enrollment_attrs = %{
      "user_id" => user_id,
      "is_current" => true,
      "start_date" => start_date,
      "group_id" => group.child_id,
      "group_type" => "batch",
      "academic_year" => academic_year
    }

    # Update existing batch enrollments to not current
    update_existing_enrollments(user_id, "batch", start_date)

    case EnrollmentRecords.create_enrollment_record(enrollment_attrs) do
      {:ok, _} ->
        # Update or create group-user
        update_or_create_group_user(user_id, group_id)
        {:ok, "Batch enrollment created"}

      error ->
        error
    end
  end

  defp create_school_enrollment(user_id, params, start_date, academic_year) do
    school_code = Map.get(params, "school_code")
    process_school_enrollment(user_id, school_code, start_date, academic_year)
  end

  defp process_school_enrollment(user_id, school_code, start_date, academic_year) do
    case EnrollmentService.get_school_group_id(school_code) do
      {:error, error_msg} ->
        {:error, error_msg}

      group_id ->
        create_school_enrollment_record(user_id, group_id, start_date, academic_year)
    end
  end

  defp create_school_enrollment_record(user_id, group_id, start_date, academic_year) do
    group = Groups.get_group!(group_id)

    enrollment_attrs = %{
      "user_id" => user_id,
      "is_current" => true,
      "start_date" => start_date,
      "group_id" => group.child_id,
      "group_type" => "school",
      "academic_year" => academic_year
    }

    # Update existing school enrollments to not current
    update_existing_enrollments(user_id, "school", start_date)

    case EnrollmentRecords.create_enrollment_record(enrollment_attrs) do
      {:ok, _} ->
        # Update or create group-user
        update_or_create_group_user(user_id, group_id)
        {:ok, "School enrollment created"}

      error ->
        error
    end
  end

  defp create_auth_group_enrollment(user_id, params, start_date) do
    case Map.get(params, "auth_group") do
      nil ->
        {:error, "Auth group is required for re-enrollment"}

      auth_group_name ->
        process_auth_group_enrollment(user_id, auth_group_name, start_date)
    end
  end

  defp process_auth_group_enrollment(user_id, auth_group_name, start_date) do
    case EnrollmentService.get_auth_group_id(auth_group_name) do
      {:error, error_msg} ->
        {:error, error_msg}

      group_id ->
        create_auth_group_enrollment_record(user_id, group_id, start_date)
    end
  end

  defp create_auth_group_enrollment_record(user_id, group_id, start_date) do
    group = Groups.get_group!(group_id)

    # Find the existing auth_group enrollment record for this user
    # Match on group.child_id since enrollment records store child_id, not group.id
    existing_enrollment =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_id == ^group.child_id and
            er.group_type == "auth_group",
        order_by: [desc: er.inserted_at],
        limit: 1
      )
      |> Repo.one()

    case existing_enrollment do
      nil ->
        # If no existing record found, create a new one
        enrollment_attrs = %{
          "user_id" => user_id,
          "is_current" => true,
          "start_date" => start_date,
          "group_id" => group.child_id,
          "group_type" => "auth_group"
        }

        case EnrollmentRecords.create_enrollment_record(enrollment_attrs) do
          {:ok, _} ->
            # Update or create group-user
            update_or_create_group_user(user_id, group_id)
            {:ok, "Auth group enrollment created"}

          error ->
            error
        end

      enrollment ->
        # Mark any other current auth_group enrollments as not current
        # Exclude the enrollment we're about to reactivate to avoid double updates
        update_other_auth_group_enrollments(user_id, enrollment.id, start_date)

        # Reactivate the existing enrollment record
        case EnrollmentRecords.update_enrollment_record(enrollment, %{
               "is_current" => true,
               "end_date" => nil
             }) do
          {:ok, _} ->
            # Update or create group-user
            update_or_create_group_user(user_id, group_id)
            {:ok, "Auth group enrollment reactivated"}

          error ->
            error
        end
    end
  end

  defp update_existing_enrollments(user_id, group_type, end_date) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_type == ^group_type and
          er.is_current == true,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end

  defp update_other_auth_group_enrollments(user_id, exclude_enrollment_id, end_date) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_type == "auth_group" and
          er.is_current == true and
          er.id != ^exclude_enrollment_id,
      update: [set: [is_current: false, end_date: ^end_date]]
    )
    |> Repo.update_all([])
  end

  defp update_or_create_group_user(user_id, group_id) do
    group = Groups.get_group!(group_id)
    group_type = group.type

    # Get all group IDs that match this type using a subquery
    group_ids_subquery =
      from(g in Group,
        where: g.type == ^group_type,
        select: g.id
      )

    # Delete all existing group-user entries for this user and group type
    {_deleted_count, _} =
      from(gu in GroupUser,
        where: gu.user_id == ^user_id and gu.group_id in subquery(group_ids_subquery)
      )
      |> Repo.delete_all()

    # Create a new group-user entry for the new group_id
    GroupUsers.create_group_user(%{"user_id" => user_id, "group_id" => group_id})
  end
end
