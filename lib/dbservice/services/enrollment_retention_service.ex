defmodule Dbservice.Services.EnrollmentRetentionService do
  @moduledoc """
  Handles retention clean-up for enrollment and group-user records coming from
  the "Remove Wrong Enrollment Records" import.

  If the sheet marks a record as not retained, the corresponding group-user
  entry and enrollment record are deleted for that student.
  """

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  @doc """
  Processes a single retention row.

  Expects `retain_record` to be a boolean (converted from the sheet via
  boolean field mapping). Returns:
    * `{:ok, :retained}` when the row is marked to retain
    * `{:ok, :deleted}` when matching records are removed
    * `{:error, reason}` on validation failures
  """
  def process_retention(record) do
    retain_flag =
      record
      |> Map.get("retain_record")
      |> normalize_boolean()

    with :ok <- validate_retain_flag(retain_flag) do
      # If retain is true, short-circuit without any lookups or deletes
      # to avoid failing on missing groups/students when we intend to keep data.
      if retain_flag == true do
        {:ok, :retained}
      else
        with {:ok, student} <- fetch_student(record),
             {:ok, group} <- fetch_group(record) do
          apply_action(retain_flag, student.user_id, group, record)
        end
      end
    end
  end

  defp validate_retain_flag(flag) when is_boolean(flag), do: :ok

  defp validate_retain_flag(nil),
    do: {:error, "\"Should it be retained?\" column is required for each row"}

  defp validate_retain_flag(flag),
    do: {:error, "Invalid value for \"Should it be retained?\": #{inspect(flag)}"}

  defp normalize_boolean(nil), do: nil
  defp normalize_boolean(flag) when is_boolean(flag), do: flag

  defp normalize_boolean(flag) when is_integer(flag) do
    case flag do
      1 -> true
      0 -> false
      _ -> flag
    end
  end

  defp normalize_boolean(flag) when is_binary(flag) do
    case flag |> String.trim() |> String.downcase() do
      "yes" -> true
      "true" -> true
      "1" -> true
      "no" -> false
      "false" -> false
      "0" -> false
      other -> other
    end
  end

  defp normalize_boolean(flag), do: flag

  defp fetch_student(record) do
    case Users.get_student_by_id_or_apaar_id(record) do
      nil ->
        {:error,
         "Student not found. student_id: #{Map.get(record, "student_id")}, apaar_id: #{Map.get(record, "apaar_id")}"}

      student ->
        {:ok, student}
    end
  end

  defp fetch_group(%{"group_id" => raw_group_id, "group_type" => group_type}) do
    normalized_group_type = normalize_group_type(group_type)

    with {:ok, child_id} <- parse_integer(raw_group_id),
         :ok <- validate_group_type(normalized_group_type),
         %Group{} = group <-
           Groups.get_group_by_child_id_and_type(child_id, normalized_group_type) do
      {:ok, group}
    else
      nil ->
        {:error,
         "Group not found for group_id #{inspect(raw_group_id)} with group_type #{inspect(group_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_group(_),
    do: {:error, "Both group_id and group_type are required to locate the enrollment"}

  defp validate_group_type(group_type) when is_binary(group_type) and group_type != "", do: :ok
  defp validate_group_type(_), do: {:error, "group_type is required to locate the enrollment"}

  defp normalize_group_type(group_type) when is_binary(group_type), do: String.trim(group_type)
  defp normalize_group_type(group_type), do: group_type

  defp parse_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_integer(value) when is_binary(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      _ -> {:error, "Invalid group_id #{inspect(value)}"}
    end
  end

  defp parse_integer(value), do: {:error, "Invalid group_id #{inspect(value)}"}

  defp apply_action(true, _user_id, _group, _record), do: {:ok, :retained}

  defp apply_action(false, user_id, %Group{} = group, record) do
    group_type = normalize_group_type(Map.get(record, "group_type"))
    academic_year = Map.get(record, "academic_year")

    with :ok <- validate_academic_year(group_type, academic_year) do
      delete_enrollment_records(user_id, group.child_id, group_type, academic_year)
      delete_group_user(user_id, group.id)

      {:ok, :deleted}
    end
  end

  defp delete_enrollment_records(user_id, child_group_id, group_type, academic_year) do
    base_query =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_type == ^group_type and
            er.group_id == ^child_group_id
      )

    query =
      if group_type == "auth_group" or not present?(academic_year) do
        base_query
      else
        from(er in base_query, where: er.academic_year == ^academic_year)
      end

    Repo.delete_all(query)
  end

  defp delete_group_user(user_id, group_id) do
    from(gu in GroupUser, where: gu.user_id == ^user_id and gu.group_id == ^group_id)
    |> Repo.delete_all()

    {:ok, :deleted}
  end

  defp validate_academic_year("auth_group", _), do: :ok

  defp validate_academic_year(_group_type, academic_year) do
    if present?(academic_year) do
      :ok
    else
      {:error, "academic_year is required for this group_type"}
    end
  end

  defp present?(value), do: not is_nil(value) and value != ""
end
