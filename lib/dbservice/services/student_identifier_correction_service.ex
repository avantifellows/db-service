defmodule Dbservice.Services.StudentIdentifierCorrectionService do
  @moduledoc """
  Corrects a student's business identifiers - `student_id` and `apaar_id` - keyed
  on `user_id`.

  Ops confirmed the Update Student Details import never changes identifiers, so
  that import cross-checks them and this is the only import that moves them. The
  new values are validated against whoever already holds them before the write:

    * `apaar_id` is globally unique, so any other student holding it fails the row;
    * `student_id` is unique only *within an auth group* - 476 student_ids in
      production legitimately match two students in different groups - so it is
      checked inside the student's current auth group. A student with no current
      auth group has nothing to scope by, so the check falls back to a global one
      rather than letting an unverifiable duplicate through.
  """

  import Ecto.Query

  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Student

  @doc """
  Applies the row's new identifiers to `student`.

  Returns `{:ok, student}` or `{:error, message}`.
  """
  def process_correction(student, record) do
    new_student_id = trimmed(record["new_student_id"])
    new_apaar_id = trimmed(record["new_apaar_id"])

    if blank?(new_student_id) and blank?(new_apaar_id) do
      {:error, "A row must carry new_student_id or new_apaar_id to correct"}
    else
      correct(student, new_student_id, new_apaar_id)
    end
  end

  defp correct(student, new_student_id, new_apaar_id) do
    Repo.transaction(fn ->
      with {:ok, student} <- lock_student(student.id),
           :ok <- validate_student_id(student, new_student_id),
           :ok <- validate_apaar_id(student, new_apaar_id),
           {:ok, updated_student} <-
             Users.update_student(student, changes(new_student_id, new_apaar_id)) do
        updated_student
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(format_error(changeset))
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp lock_student(student_id) do
    case from(s in Student, where: s.id == ^student_id, lock: "FOR UPDATE") |> Repo.one() do
      nil -> {:error, "Student not found"}
      student -> {:ok, student}
    end
  end

  defp changes(new_student_id, new_apaar_id) do
    %{}
    |> maybe_put("student_id", new_student_id)
    |> maybe_put("apaar_id", new_apaar_id)
  end

  defp maybe_put(attrs, _key, value) when value in [nil, ""], do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  defp validate_student_id(_student, value) when value in [nil, ""], do: :ok

  defp validate_student_id(student, value) do
    case holder_of_student_id(student, value) do
      nil ->
        :ok

      holder_id when holder_id == student.id ->
        :ok

      _other ->
        {:error,
         "student_id '#{value}' already belongs to another student in this student's " <>
           "auth group"}
    end
  end

  defp holder_of_student_id(student, value) do
    case current_auth_group_id(student.user_id) do
      nil -> any_other_holder(student, value)
      auth_group_id -> holder_in_auth_group(student, value, auth_group_id)
    end
  end

  defp holder_in_auth_group(student, value, auth_group_id) do
    from(s in Student,
      join: er in EnrollmentRecord,
      on:
        er.user_id == s.user_id and er.group_type == "auth_group" and
          er.group_id == ^auth_group_id and er.is_current == true,
      where: s.student_id == ^value and s.id != ^student.id,
      select: s.id,
      limit: 1
    )
    |> Repo.one()
  end

  # No current auth group means nothing to scope the uniqueness by, so any other
  # holder is treated as a conflict rather than assumed to be in another group.
  defp any_other_holder(student, value) do
    from(s in Student,
      where: s.student_id == ^value and s.id != ^student.id,
      select: s.id,
      limit: 1
    )
    |> Repo.one()
  end

  defp current_auth_group_id(user_id) do
    from(er in EnrollmentRecord,
      where: er.user_id == ^user_id and er.group_type == "auth_group" and er.is_current == true,
      select: er.group_id,
      limit: 1
    )
    |> Repo.one()
  end

  defp validate_apaar_id(_student, value) when value in [nil, ""], do: :ok

  defp validate_apaar_id(student, value) do
    Users.validate_identifier_conflicts(%{"apaar_id" => value}, student)
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    if changeset.errors != [] do
      "Failed to correct identifiers: #{inspect(changeset.errors)}"
    else
      "Failed to correct identifiers"
    end
  end

  defp trimmed(value) when is_binary(value), do: String.trim(value)
  defp trimmed(value), do: value

  defp blank?(value), do: is_nil(value) or value == ""
end
