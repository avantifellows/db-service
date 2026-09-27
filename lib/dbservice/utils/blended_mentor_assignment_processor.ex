defmodule Dbservice.DataImport.BlendedMentorAssignmentProcessor do
  @moduledoc """
  Row processor for the Blended Learning Mentor Assignment import.

  Resolves a CSV row (student, mentor email, program, academic year) into a
  mentor-mentee mapping. The mentor is an ordinary `user` row: it is looked up by
  email, and created from the name columns when no user has that email yet, so
  ops do not have to seed the user table by hand first.
  """

  alias Dbservice.BlendedLearning
  alias Dbservice.Users
  alias Dbservice.Utils.ChangesetFormatter

  @mentor_role "mentor"

  def process_mentor_assignment(record) do
    with {:ok, student} <- get_student(record),
         {:ok, program_id} <- get_program_id(record),
         {:ok, academic_year} <- get_academic_year(record),
         {:ok, started_at} <- get_started_at(record),
         {:ok, assigned_by_email} <- get_assigned_by_email(record),
         {:ok, audit_reason} <- get_audit_reason(record),
         {:ok, mentor} <- find_or_create_mentor(record) do
      %{
        student_id: student.id,
        mentor_user_id: mentor.id,
        program_id: program_id,
        academic_year: academic_year,
        started_at: started_at,
        assigned_by_user_id: assigned_by_user_id(assigned_by_email),
        assigned_by_email: assigned_by_email,
        assignment_audit_reason: audit_reason
      }
      |> BlendedLearning.assign_mentor()
      |> describe_outcome(mentor)
    end
  end

  defp describe_outcome({:ok, :assigned}, mentor),
    do: {:ok, "Mentor #{mentor.email} assigned"}

  defp describe_outcome({:ok, :reassigned}, mentor),
    do: {:ok, "Mentor changed to #{mentor.email}; previous mapping ended"}

  defp describe_outcome({:ok, :unchanged}, mentor),
    do: {:ok, "Mentor #{mentor.email} already assigned, no change"}

  defp describe_outcome({:error, reason}, _mentor) when is_binary(reason),
    do: {:error, "Mentor assignment failed: #{reason}"}

  defp describe_outcome({:error, reason}, _mentor),
    do: {:error, "Mentor assignment failed: #{inspect(reason)}"}

  defp get_student(record) do
    student_id = trimmed(record["student_id"])
    apaar_id = trimmed(record["apaar_id"])

    if is_nil(student_id) and is_nil(apaar_id) do
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

  # program_id is filled in by the import worker when it resolves program_name;
  # an unknown name leaves it blank, which is the error worth reporting.
  defp get_program_id(record) do
    case record["program_id"] do
      nil -> {:error, program_lookup_error(record)}
      program_id -> {:ok, program_id}
    end
  end

  defp program_lookup_error(record) do
    case trimmed(record["program_name"]) do
      nil -> "program_name is required"
      name -> "Program not found with name: #{name}"
    end
  end

  defp get_academic_year(record) do
    case trimmed(record["academic_year"]) do
      nil -> {:error, "academic_year is required"}
      year -> {:ok, year}
    end
  end

  defp get_assigned_by_email(record) do
    case trimmed(record["assigned_by_email"]) do
      nil -> {:error, "assigned_by_email is required"}
      email -> {:ok, email}
    end
  end

  defp get_audit_reason(record), do: {:ok, trimmed(record["assignment_audit_reason"])}

  # Blank means the mentorship starts now; a value is how an assignment entered
  # late gets backdated to when it actually began.
  defp get_started_at(record) do
    case trimmed(record["started_at"]) do
      nil -> {:ok, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}
      value -> parse_started_at(value)
    end
  end

  defp parse_started_at(value) do
    with :error <- parse_date(value),
         :error <- parse_naive_datetime(value),
         :error <- parse_utc_datetime(value) do
      {:error,
       "started_at '#{value}' is not a valid date; use YYYY-MM-DD or an ISO-8601 date and time"}
    end
  end

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, NaiveDateTime.new!(date, ~T[00:00:00])}
      {:error, _reason} -> :error
    end
  end

  defp parse_naive_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> {:ok, NaiveDateTime.truncate(naive, :second)}
      {:error, _reason} -> :error
    end
  end

  defp parse_utc_datetime(value) do
    case DateTime.from_iso8601(value) do
      # from_iso8601/1 has already converted any offset to UTC.
      {:ok, datetime, _offset} ->
        {:ok, datetime |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)}

      {:error, _reason} ->
        :error
    end
  end

  # The assigner may be an admin with no user record, which is why the mapping
  # keeps an email alongside the optional user id.
  defp assigned_by_user_id(email) do
    case Users.get_user_by_email(email) do
      nil -> nil
      user -> user.id
    end
  end

  defp find_or_create_mentor(record) do
    case trimmed(record["mentor_email"]) do
      nil ->
        {:error, "mentor_email is required"}

      email ->
        case Users.get_user_by_email(email) do
          nil -> create_mentor(email, record)
          user -> {:ok, user}
        end
    end
  end

  defp create_mentor(email, record) do
    case trimmed(record["mentor_first_name"]) do
      nil ->
        {:error,
         "No user found for mentor email #{email}; mentor_first_name is required to create one"}

      first_name ->
        insert_mentor(email, first_name, trimmed(record["mentor_last_name"]))
    end
  end

  defp insert_mentor(email, first_name, last_name) do
    case Users.create_user(%{
           "first_name" => first_name,
           "last_name" => last_name,
           "email" => email,
           "role" => @mentor_role
         }) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, "Could not create mentor user: #{ChangesetFormatter.format_errors(changeset)}"}
    end
  end

  defp trimmed(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trimmed(_value), do: nil
end
