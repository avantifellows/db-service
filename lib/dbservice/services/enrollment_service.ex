defmodule Dbservice.Services.EnrollmentService do
  @moduledoc """
  Shared service for handling group user enrollments.
  This module contains reusable functions for creating and updating group user enrollments
  across different parts of the application.

  Ensures that users can only be enrolled in one school, grade, or auth_group at a time.
  """

  import Ecto.Query
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.AuthGroups
  alias Dbservice.Schools
  alias Dbservice.Batches
  alias Dbservice.Grades
  alias Dbservice.EnrollmentRecords
  alias Dbservice.Groups.GroupUser
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Repo

  # Group types that should be exclusive (only one active at a time)
  @exclusive_group_types ["school", "grade", "auth_group"]

  @doc """
  Creates or updates a group user enrollment based on the enrollment type.
  """
  def process_enrollment(%{"enrollment_type" => "auth_group"} = data) do
    case get_auth_group_id(data["auth_group"]) do
      {:error, error_msg} -> {:error, error_msg}
      group_id -> handle_group_user_enrollment(Map.put(data, "group_id", group_id))
    end
  end

  def process_enrollment(%{"enrollment_type" => "school"} = data) do
    case get_school_group_id(data["school_code"]) do
      {:error, error_msg} -> {:error, error_msg}
      group_id -> handle_group_user_enrollment(Map.put(data, "group_id", group_id))
    end
  end

  def process_enrollment(%{"enrollment_type" => "batch"} = data) do
    case get_batch_group_id(data["batch_id"]) do
      {:error, error_msg} -> {:error, error_msg}
      group_id -> handle_group_user_enrollment(Map.put(data, "group_id", group_id))
    end
  end

  def process_enrollment(%{"enrollment_type" => "grade"} = data) do
    case get_grade_group_id(data["grade_id"]) do
      {:error, error_msg} -> {:error, error_msg}
      group_id -> handle_group_user_enrollment(Map.put(data, "group_id", group_id))
    end
  end

  def process_enrollment(_data), do: {:error, "Unknown enrollment type"}

  @doc """
  Creates or updates a group user enrollment for a specific group.
  Validates that user doesn't have existing active enrollments for exclusive group types.
  """
  def handle_group_user_enrollment(params) do
    group = Groups.get_group!(params["group_id"])

    # If this is an exclusive group type, validate no existing active enrollments
    if group.type in @exclusive_group_types do
      case validate_no_existing_enrollment(params["user_id"], group.type, params["group_id"]) do
        :ok -> :continue
        {:error, reason} -> {:error, reason}
      end
    end

    case GroupUsers.get_group_user_by_user_id_and_group_id(
           params["user_id"],
           params["group_id"]
         ) do
      nil -> create_new_group_user(params)
      existing_group_user -> update_existing_group_user(existing_group_user, params)
    end
  end

  @doc """
  Validates that a user doesn't have any other active enrollments for the given group type.
  Returns {:error, reason} if an active enrollment exists, :ok otherwise.
  """
  def validate_no_existing_enrollment(user_id, group_type, current_group_id) do
    query =
      from g in Groups,
        join: gu in GroupUser,
        on: gu.group_id == g.id,
        where:
          g.type == ^group_type and
            gu.user_id == ^user_id and
            g.id != ^current_group_id and
            gu.is_active == true,
        select: %{group_id: g.id, child_id: g.child_id, type: g.type}

    case Repo.all(query) do
      [] ->
        :ok

      [existing | _] ->
        {:error, build_duplicate_enrollment_error(existing, group_type)}
    end
  end

  @doc """
  Builds a descriptive error message for duplicate enrollment attempts.
  """
  defp build_duplicate_enrollment_error(existing_enrollment, group_type) do
    group_name = get_group_name(existing_enrollment.child_id, group_type)

    case group_type do
      "school" ->
        "Student is already enrolled in school: #{group_name}. Use 'update_incorrect_school_to_correct_school' import type to change schools."

      "grade" ->
        "Student is already enrolled in grade: #{group_name}. Use 'update_incorrect_grade_to_correct_grade' import type to change grades."

      "auth_group" ->
        "Student is already enrolled in auth_group: #{group_name}. Use 'update_incorrect_auth_group_to_correct_auth_group' import type to change auth groups."

      _ ->
        "Student is already enrolled in this #{group_type}. Use the appropriate update import type."
    end
  end

  @doc """
  Gets the display name for a group based on its type and child_id.
  """
  defp get_group_name(child_id, group_type) do
    case group_type do
      "school" ->
        case Schools.get_school(child_id) do
          nil -> "Unknown School"
          school -> school.code || "School ##{child_id}"
        end

      "grade" ->
        case Grades.get_grade(child_id) do
          nil -> "Unknown Grade"
          grade -> "Grade #{grade.number}"
        end

      "auth_group" ->
        case AuthGroups.get_auth_group(child_id) do
          nil -> "Unknown Auth Group"
          auth_group -> auth_group.name
        end

      _ ->
        "Unknown"
    end
  end

  @doc """
  Validates enrollment before creation (can be called from import workers).
  Returns :ok if enrollment is allowed, {:error, reason} otherwise.
  """
  def validate_enrollment(%{"enrollment_type" => enrollment_type} = data) do
    group_id =
      case enrollment_type do
        "auth_group" ->
          case get_auth_group_id(data["auth_group"]) do
            {:error, _} = err -> err
            id -> id
          end

        "school" ->
          case get_school_group_id(data["school_code"]) do
            {:error, _} = err -> err
            id -> id
          end

        "grade" ->
          case get_grade_group_id(data["grade_id"]) do
            {:error, _} = err -> err
            id -> id
          end

        "batch" ->
          case get_batch_group_id(data["batch_id"]) do
            {:error, _} = err -> err
            id -> id
          end

        _ ->
          {:error, "Unknown enrollment type"}
      end

    case group_id do
      {:error, _} = err ->
        err

      id ->
        group = Groups.get_group!(id)

        if group.type in @exclusive_group_types do
          validate_no_existing_enrollment(data["user_id"], group.type, id)
        else
          :ok
        end
    end
  end

  @doc """
  Creates a new group user with associated enrollment record.
  """
  def create_new_group_user(params) do
    group = Groups.get_group!(params["group_id"])
    academic_year = resolve_academic_year(group.type, params)

    enrollment_record = %{
      "group_id" => group.child_id,
      "group_type" => group.type,
      "user_id" => params["user_id"],
      "academic_year" => academic_year,
      "start_date" => params["start_date"]
    }

    with {:ok, %EnrollmentRecord{} = _} <-
           EnrollmentRecords.create_enrollment_record(enrollment_record),
         {:ok, %GroupUser{} = group_user} <- GroupUsers.create_group_user(params) do
      {:ok, group_user}
    else
      {:error, _changeset} -> {:error, "Failed to create group user"}
    end
  end

  @doc """
  Updates an existing group user.
  """
  def update_existing_group_user(existing_group_user, params) do
    group = Groups.get_group!(params["group_id"])

    if Map.has_key?(params, "academic_year") and group.type == "school" do
      update_school_enrollment(
        params["user_id"],
        group.child_id,
        params["academic_year"],
        params["start_date"]
      )

      handle_enrollment_record(
        params["user_id"],
        group.child_id,
        group.type,
        params["academic_year"],
        params["start_date"]
      )
    end

    case GroupUsers.update_group_user(existing_group_user, params) do
      {:ok, group_user} -> {:ok, group_user}
      {:error, _changeset} -> {:error, "Failed to update group user"}
    end
  end

  @doc """
  Gets the group ID for an auth group by name.
  """
  def get_auth_group_id(auth_group_name) do
    case AuthGroups.get_auth_group_by_name(auth_group_name) do
      nil ->
        {:error, "Auth group not found with name: #{auth_group_name}"}

      auth_group ->
        case Groups.get_group_by_child_id_and_type(auth_group.id, "auth_group") do
          nil -> {:error, "Auth group not found with name: #{auth_group_name}"}
          group -> group.id
        end
    end
  end

  @doc """
  Gets the group ID for a school by school code.
  """
  def get_school_group_id(school_code) do
    case Schools.get_school_by_code(school_code) do
      nil ->
        {:error, "School not found with code: #{school_code}"}

      school ->
        case Groups.get_group_by_child_id_and_type(school.id, "school") do
          nil -> {:error, "School group not found with code: #{school_code}"}
          group -> group.id
        end
    end
  end

  @doc """
  Gets the group ID for a batch by batch ID.
  """
  def get_batch_group_id(batch_id) do
    case Batches.get_batch_by_batch_id(batch_id) do
      nil ->
        {:error, "Batch not found with id: #{batch_id}"}

      batch ->
        case Groups.get_group_by_child_id_and_type(batch.id, "batch") do
          nil -> {:error, "Batch group not found with id: #{batch_id}"}
          group -> group.id
        end
    end
  end

  @doc """
  Gets the group ID for a grade by grade ID.
  """
  def get_grade_group_id(grade_id) do
    case Grades.get_grade(grade_id) do
      nil ->
        {:error, "Grade not found with id: #{grade_id}"}

      grade ->
        case Groups.get_group_by_child_id_and_type(grade.id, "grade") do
          nil -> {:error, "Grade group not found with id: #{grade_id}"}
          group -> group.id
        end
    end
  end

  @doc """
  Resolves the academic year based on group type.
  Auth groups don't need academic year, others do.
  """
  def resolve_academic_year(group_type, params) do
    if group_type == "auth_group" do
      nil
    else
      params["academic_year"]
    end
  end

  @doc """
  Updates previous enrollment records for a user in a school when the academic year changes.
  """
  def update_school_enrollment(user_id, school_id, new_academic_year, end_date) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_id == ^school_id and
          er.group_type == "school" and
          er.academic_year != ^new_academic_year and
          er.is_current == true
    )
    |> Repo.all()
    |> Enum.each(fn record ->
      EnrollmentRecords.update_enrollment_record(record, %{
        "is_current" => false,
        "end_date" => end_date
      })
    end)
  end

  @doc """
  Ensures an enrollment record exists for the given user, group, type, and academic year. Creates one if not present.
  """
  def handle_enrollment_record(user_id, group_id, group_type, academic_year, start_date) do
    import Ecto.Query

    enrollment_record =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_id == ^group_id and
            er.group_type == ^group_type and
            er.academic_year == ^academic_year
      )
      |> Repo.one()

    if is_nil(enrollment_record) do
      enrollment_record_params = %{
        "group_id" => group_id,
        "group_type" => group_type,
        "user_id" => user_id,
        "academic_year" => academic_year,
        "start_date" => start_date
      }

      EnrollmentRecords.create_enrollment_record(enrollment_record_params)
    end
  end
end
