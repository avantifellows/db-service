defmodule Dbservice.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
  alias Dbservice.Repo

  alias Dbservice.AuthGroups
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Services.EnrollmentService

  alias Dbservice.Users.User

  @doc """
  Returns the list of user.

  ## Examples

      iex> list_user()
      [%User{}, ...]

  """
  def list_all_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by user ID.
  Raises `Ecto.NoResultsError` if the User does not exist.
  ## Examples
      iex> get_user_by_user_id(1234)
      %User{}
      iex> get_user_by_user_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_user_by_user_id(user_id) do
    Repo.get(User, user_id)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Updates the group mapped to a user.
  """
  def update_group(user_id, group_ids) when is_list(group_ids) do
    user = get_user!(user_id)

    groups =
      Dbservice.Groups.Group
      |> where([group], group.id in ^group_ids)
      |> Repo.all()

    user
    |> Repo.preload(:group)
    |> User.changeset_update_groups(groups)
    |> Repo.update()
  end

  alias Dbservice.Users.Student

  @doc """
  Returns the list of student.

  ## Examples

      iex> list_student()
      [%Student{}, ...]

  """
  def list_student do
    Repo.all(Student)
  end

  @doc """
  Gets a single student.

  Raises `Ecto.NoResultsError` if the Student does not exist.

  ## Examples

      iex> get_student!(123)
      %Student{}

      iex> get_student!(456)
      ** (Ecto.NoResultsError)

  """
  def get_student!(id), do: Repo.get!(Student, id)

  @doc """
  Gets a student by `student_id`, or `nil` if none exists.

  `student_id` is not globally unique - the same id can exist across auth groups. Pass a
  params map carrying `auth_group` (name) or `auth_group_id` to get an unambiguous,
  auth-group-scoped match (the student in *that* group, or `nil`). This is what identity-
  sensitive callers should do so they never act on another auth group's student.

  Without a resolvable auth group it falls back to the earliest-created matching student,
  rather than raising `Ecto.MultipleResultsError` (which `Repo.get_by/2` would on duplicates).

  ## Examples
      iex> get_student_by_student_id("1234")
      %Student{}
      iex> get_student_by_student_id("1234", %{"auth_group" => "DelhiStudents"})
      %Student{}
      iex> get_student_by_student_id("does-not-exist")
      nil
  """
  def get_student_by_student_id(student_id, auth_group_params \\ %{}) do
    case resolve_auth_group_id(auth_group_params) do
      nil -> get_student_by_student_id_unscoped(student_id)
      auth_group_id -> get_student_by_student_id_and_auth_group(student_id, auth_group_id)
    end
  end

  defp get_student_by_student_id_unscoped(student_id) do
    from(s in Student,
      where: s.student_id == ^student_id,
      order_by: [asc: s.id],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets a student by user ID.
  Returns nil if no student exists for the given user_id.
  """
  def get_student_by_user_id(user_id) do
    Repo.get_by(Student, user_id: user_id)
  end

  @doc """
  Gets a student by student ID or APAAR ID, in that order.

  ## Examples

      iex> get_student_by_id_or_apaar_id(%{"student_id" => "1234", "apaar_id" => nil})
      %Student{}
      iex> get_student_by_id_or_apaar_id(%{"student_id" => nil, "apaar_id" => "123456789101"})
      %Student{}
      iex> get_student_by_id_or_apaar_id(%{"student_id" => nil, "apaar_id" => nil})
      nil
  """
  def get_student_by_id_or_apaar_id(record) when is_map(record) do
    find_student(:student_id, record["student_id"]) ||
      find_student(:apaar_id, record["apaar_id"])
  end

  def get_student_by_id_pen_or_apaar_id(record) when is_map(record) do
    [
      find_student(:student_id, record["student_id"]),
      find_student(:pen_number, record["pen_number"]),
      find_student(:apaar_id, record["apaar_id"])
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
    |> case do
      [] -> nil
      [student] -> student
      _students -> {:error, :conflicting_identifiers}
    end
  end

  defp find_student(_field, value) when value in [nil, ""], do: nil
  defp find_student(field, value), do: Repo.get_by(Student, [{field, value}])

  @doc """
  Gets a student scoped to an auth group.

  A `student_id` is only unique within the scope of an auth group, so a student is the
  *same logical student* only when its `student_id` matches AND there is an enrollment
  record tying it to the given auth group (`group_type = "auth_group"`,
  `group_id = auth_group.id`).

  By default only a *current* (`is_current = true`) ownership record counts. Pass
  `include_inactive: true` to also match a student whose ownership record was deactivated
  (e.g. by a dropout, which flips all current records to `is_current = false`) - the
  create/update path uses this so re-POSTing a dropped student revives the same row rather
  than inserting a duplicate. A current record is preferred when both exist.

  Returns the matching `%Student{}` or `nil`.
  """
  def get_student_by_student_id_and_auth_group(student_id, auth_group_id, opts \\ [])

  def get_student_by_student_id_and_auth_group(student_id, auth_group_id, opts)
      when not is_nil(student_id) and not is_nil(auth_group_id) do
    base =
      from(s in Student,
        join: er in EnrollmentRecord,
        on: er.user_id == s.user_id,
        where:
          s.student_id == ^student_id and
            er.group_type == "auth_group" and
            er.group_id == ^auth_group_id,
        order_by: [desc: er.is_current, asc: s.id],
        limit: 1
      )

    query =
      if Keyword.get(opts, :include_inactive, false) do
        base
      else
        from([_s, er] in base, where: er.is_current == true)
      end

    Repo.one(query)
  end

  def get_student_by_student_id_and_auth_group(_student_id, _auth_group_id, _opts), do: nil

  @doc """
  Resolves the incoming auth group id from request/import params.

  Prefers an explicit `auth_group_id` (the data-import pipeline already sets this to
  `auth_group.id`); otherwise resolves the `auth_group` name via `AuthGroups`.
  Returns the `auth_group.id` (which is what enrollment records store as `group_id`),
  or `nil` when no auth group can be determined.
  """
  def resolve_auth_group_id(params) do
    case params["auth_group_id"] do
      id when not is_nil(id) and id != "" ->
        id

      _ ->
        resolve_auth_group_id_by_name(params["auth_group"])
    end
  end

  defp resolve_auth_group_id_by_name(name) when is_binary(name) and name != "" do
    case AuthGroups.get_auth_group_by_name(name) do
      nil -> nil
      auth_group -> auth_group.id
    end
  end

  defp resolve_auth_group_id_by_name(_name), do: nil

  @doc """
  Creates a student.

  ## Examples

      iex> create_student(%{field: value})
      {:ok, %Student{}}

      iex> create_student(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_student(attrs \\ %{}) do
    %Student{}
    |> Student.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a student.

  ## Examples

      iex> update_student(student, %{field: new_value})
      {:ok, %Student{}}

      iex> update_student(student, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_student(%Student{} = student, attrs) do
    student
    |> Student.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a student.

  ## Examples

      iex> delete_student(student)
      {:ok, %Student{}}

      iex> delete_student(student)
      {:error, %Ecto.Changeset{}}

  """
  def delete_student(%Student{} = student) do
    Repo.delete(student)
  end

  @doc """
  Creates a user first and then the student.

  ## Examples

      iex> create_student_with_user(%{field: value})
      {:ok, %Student{}}

      iex> create_student_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_student_with_user(attrs \\ %{}) do
    alias Dbservice.Users

    Repo.transaction(fn ->
      with {:ok, %User{} = user} <- Users.create_user(attrs),
           {:ok, %Student{} = student} <-
             Users.create_student(Map.merge(stringify_keys(attrs), %{"user_id" => user.id})) do
        student
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Updates a user first and then the student.

  ## Examples

      iex> update_student_with_user(%{field: value})
      {:ok, %Student{}}

      iex> update_student_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_student_with_user(student, user, attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.update_user(user, attrs),
         {:ok, %Student{} = student} <-
           Users.update_student(
             student,
             Map.merge(stringify_keys(attrs), %{"user_id" => user.id})
           ) do
      {:ok, student}
    end
  end

  @doc """
  Creates or updates a student based on student_id or apaar_id.
  Validates that identifiers are not duplicated before creating/updating.
  This function can be used by both API endpoints and LiveView forms.

  ## Parameters
  - params: Map containing student and user data, including student_id and/or apaar_id

  ## Returns
  - {:ok, student} if successful
  - {:error, reason} if validation fails or operation fails

  ## Examples

      iex> create_or_update_student(%{"student_id" => "1234", "apaar_id" => "123456789101"})
      {:ok, %Student{}}

      iex> create_or_update_student(%{"student_id" => "1234", "apaar_id" => "123456789101"})
      {:error, "Student ID '1234' already exists for another student"}
  """
  def create_or_update_student(params) do
    student_id = params["student_id"]
    apaar_id = params["apaar_id"]

    # Validate at least one identifier is provided
    if (is_nil(student_id) or student_id == "") and (is_nil(apaar_id) or apaar_id == "") do
      {:error, "Student ID or APAAR ID is required"}
    else
      # `student_id` is only unique within an auth group. When an auth group is provided
      # we scope the lookup to it; otherwise we fall back to the legacy global behavior so
      # callers that don't send an auth group keep working.
      case resolve_auth_group_id(params) do
        nil -> create_or_update_student_global(params)
        auth_group_id -> create_or_update_student_scoped(params, auth_group_id)
      end
    end
  end

  # Auth-group-scoped create/update. A student is the same logical student only if its
  # `student_id` matches AND it already belongs to the incoming auth group. The student
  # row and its auth-group ownership (enrollment record + group_user) are created/updated
  # atomically in a single transaction.
  defp create_or_update_student_scoped(params, auth_group_id) do
    student_id = params["student_id"]
    apaar_id = params["apaar_id"]

    # Match the logical student in this auth group even if a dropout deactivated its
    # ownership record - re-POSTing must revive that row, never create a duplicate (:466).
    existing_student =
      get_student_by_student_id_and_auth_group(student_id, auth_group_id, include_inactive: true)

    # `apaar_id` remains globally unique even though `student_id` is auth-group-scoped.
    with :ok <- validate_apaar_id_not_duplicated(apaar_id, existing_student) do
      Repo.transaction(fn ->
        case upsert_student_scoped(existing_student, params, auth_group_id) do
          {:ok, student} -> student
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  # New student: create it and establish auth-group ownership (enrollment record + group_user).
  defp upsert_student_scoped(nil, params, auth_group_id) do
    with {:ok, student} <- create_student_with_user(params),
         {:ok, _ownership} <- ensure_auth_group_ownership(student, params, auth_group_id) do
      {:ok, student}
    end
  end

  # Existing student in this auth group: update fields. Guard against silently overwriting a
  # stored `apaar_id` with a different one (:475), then revive the ownership record if a
  # prior dropout had deactivated it (:466).
  defp upsert_student_scoped(%Student{} = existing_student, params, auth_group_id) do
    user = get_user!(existing_student.user_id)

    with :ok <- validate_incoming_apaar_matches(existing_student, params),
         {:ok, student} <- update_student_with_user(existing_student, user, params) do
      reactivate_auth_group_enrollment(student.user_id, auth_group_id)
      {:ok, student}
    end
  end

  # Mirrors the global path's apaar-mismatch check: if an `apaar_id` is supplied and the
  # student already has a different one, reject rather than overwrite it.
  defp validate_incoming_apaar_matches(existing_student, params) do
    apaar_id = params["apaar_id"]

    if apaar_id && apaar_id != "" do
      validate_apaar_id_match(existing_student, params["student_id"], apaar_id)
    else
      :ok
    end
  end

  # Revives a previously-deactivated auth_group ownership record (no-op if already current),
  # so a re-POSTed (e.g. dropped) student is owned by - and findable in - this auth group again.
  defp reactivate_auth_group_enrollment(user_id, auth_group_id) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and er.group_type == "auth_group" and
          er.group_id == ^auth_group_id and er.is_current == false
    )
    |> Repo.update_all(set: [is_current: true, end_date: nil])

    :ok
  end

  # Ensures the auth-group ownership enrollment record + group_user mapping exist for the
  # student. Reuses the shared EnrollmentService, which is idempotent on the group_user
  # (an existing mapping results in an update, never a duplicate enrollment record).
  defp ensure_auth_group_ownership(%Student{} = student, params, auth_group_id) do
    auth_group_name = params["auth_group"] || auth_group_name_from_id(auth_group_id)

    enrollment_data = %{
      "enrollment_type" => "auth_group",
      "auth_group" => auth_group_name,
      "user_id" => student.user_id,
      "start_date" => params["start_date"] || Date.utc_today()
    }

    EnrollmentService.process_enrollment(enrollment_data)
  end

  defp auth_group_name_from_id(auth_group_id) do
    case AuthGroups.get_auth_group!(auth_group_id) do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp validate_apaar_id_not_duplicated(apaar_id, existing_student) do
    if apaar_id && apaar_id != "" && duplicate_exists?(:apaar_id, apaar_id, existing_student) do
      {:error, "APAAR ID '#{apaar_id}' already exists for another student"}
    else
      :ok
    end
  end

  # Legacy, globally-scoped create/update used when no auth group is supplied. Treats
  # `student_id`/`apaar_id` as globally unique (the original behavior).
  defp create_or_update_student_global(params) do
    case get_student_by_id_or_apaar_id_with_validation(params) do
      {:ok, nil} ->
        # Student doesn't exist and no duplicates - create new
        create_student_with_user(params)

      {:ok, existing_student} ->
        # Student exists and no duplicates - update
        user = get_user!(existing_student.user_id)
        update_student_with_user(existing_student, user, params)

      {:error, _reason} = error ->
        error
    end
  end

  # Gets student by identifier and validates no duplicates exist for other students
  # Returns {:ok, student} if found and validated, {:ok, nil} if not found and validated,
  # or {:error, reason} if duplicates found
  defp get_student_by_id_or_apaar_id_with_validation(params) do
    student_id = params["student_id"]
    apaar_id = params["apaar_id"]

    # Use the existing function to find student
    existing_student = get_student_by_id_or_apaar_id(params)

    # Determine which identifier was used to find the student (for validation)
    {student_by_id, student_by_apaar} =
      determine_matching_identifiers(existing_student, student_id, apaar_id)

    # Validate that if we found a student by one identifier, the other identifier matches
    # This prevents accidentally changing identifiers when they don't match
    with :ok <-
           validate_identifier_matches(
             existing_student,
             student_by_id,
             student_by_apaar,
             student_id,
             apaar_id
           ),
         :ok <- validate_identifiers_not_duplicated(student_id, apaar_id, existing_student) do
      {:ok, existing_student}
    end
  end

  defp determine_matching_identifiers(nil, _student_id, _apaar_id), do: {nil, nil}

  defp determine_matching_identifiers(existing_student, student_id, apaar_id) do
    student_by_id = check_student_id_match(existing_student, student_id)
    student_by_apaar = check_apaar_id_match(existing_student, student_by_id, apaar_id)

    {student_by_id, student_by_apaar}
  end

  defp check_student_id_match(existing_student, student_id) do
    if existing_student && student_id && student_id != "" &&
         existing_student.student_id == student_id do
      existing_student
    else
      nil
    end
  end

  defp check_apaar_id_match(existing_student, student_by_id, apaar_id) do
    if existing_student && !student_by_id && apaar_id && apaar_id != "" &&
         existing_student.apaar_id == apaar_id do
      existing_student
    else
      nil
    end
  end

  # Validates that if we found a student by one identifier, the other identifier in params matches
  # This prevents changing identifiers when they don't match the existing student
  defp validate_identifier_matches(
         nil,
         _student_by_id,
         _student_by_apaar,
         _student_id,
         _apaar_id
       ),
       do: :ok

  defp validate_identifier_matches(
         existing_student,
         student_by_id,
         student_by_apaar,
         student_id,
         apaar_id
       ) do
    cond do
      # If we found student by student_id, check that apaar_id matches (if provided)
      found_by_student_id?(student_by_id, apaar_id) ->
        validate_apaar_id_match(existing_student, student_id, apaar_id)

      # If we found student by apaar_id, check that student_id matches (if provided)
      found_by_apaar_id_only?(student_by_apaar, student_by_id, student_id) ->
        validate_student_id_match(existing_student, student_id, apaar_id)

      true ->
        :ok
    end
  end

  defp found_by_student_id?(student_by_id, apaar_id) do
    student_by_id && apaar_id && apaar_id != ""
  end

  defp found_by_apaar_id_only?(student_by_apaar, student_by_id, student_id) do
    student_by_apaar && !student_by_id && student_id && student_id != ""
  end

  defp validate_apaar_id_match(existing_student, student_id, apaar_id) do
    if existing_student.apaar_id && existing_student.apaar_id != apaar_id do
      {:error,
       "Student found with Student ID '#{student_id}' but APAAR ID '#{apaar_id}' doesn't match existing APAAR ID '#{existing_student.apaar_id}'"}
    else
      :ok
    end
  end

  defp validate_student_id_match(existing_student, student_id, apaar_id) do
    if existing_student.student_id && existing_student.student_id != student_id do
      {:error,
       "Student found with APAAR ID '#{apaar_id}' but Student ID '#{student_id}' doesn't match existing Student ID '#{existing_student.student_id}'"}
    else
      :ok
    end
  end

  @doc """
  Validates that the globally-unique identifiers in `params` (`apaar_id`, `pen_number`)
  do not already belong to another student, mirroring the student table's global unique
  constraints so a conflict is reported clearly before the write instead of surfacing as
  a raw constraint error.

  `student_id` is deliberately NOT checked here: it is only unique within an auth group
  (see `create_or_update_student/1`), so a global check would falsely flag a student
  whose id is legitimately reused in another auth group. Only the identifiers the
  database enforces globally are validated.

  Only identifiers that are present and non-empty in `params` are checked, so a partial
  update touching unrelated fields passes untouched. Accepts string or atom keys. When
  `existing_student` is given, that student is excluded from the check (re-saving its
  own identifiers is allowed); pass `nil` when validating a brand new student.

  Returns `:ok`, or `{:error, message}` naming the conflicting identifier.
  """
  def validate_identifier_conflicts(params, existing_student \\ nil) do
    apaar_id = identifier_param(params, :apaar_id)
    pen_number = identifier_param(params, :pen_number)

    cond do
      identifier_present?(apaar_id) and
          duplicate_exists?(:apaar_id, apaar_id, existing_student) ->
        {:error, "APAAR ID '#{apaar_id}' already exists for another student"}

      identifier_present?(pen_number) and
          duplicate_exists?(:pen_number, pen_number, existing_student) ->
        {:error, "PEN Number '#{pen_number}' already exists for another student"}

      true ->
        :ok
    end
  end

  defp identifier_param(params, key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  defp identifier_present?(value), do: not (is_nil(value) or value == "")

  # Validates that student_id and apaar_id are not duplicated in other students
  # When updating, validates that the NEW values in params don't conflict with other students
  defp validate_identifiers_not_duplicated(student_id, apaar_id, existing_student) do
    # Always validate both identifiers if provided, regardless of which one was used to find the student
    student_id_valid =
      if student_id && student_id != "" do
        not duplicate_exists?(:student_id, student_id, existing_student)
      else
        true
      end

    apaar_id_valid =
      if apaar_id && apaar_id != "" do
        not duplicate_exists?(:apaar_id, apaar_id, existing_student)
      else
        true
      end

    cond do
      not student_id_valid ->
        {:error, "Student ID '#{student_id}' already exists for another student"}

      not apaar_id_valid ->
        {:error, "APAAR ID '#{apaar_id}' already exists for another student"}

      true ->
        :ok
    end
  end

  defp duplicate_exists?(field, value, existing_student) do
    query =
      case field do
        :student_id -> from(s in Student, where: s.student_id == ^value)
        :apaar_id -> from(s in Student, where: s.apaar_id == ^value)
        :pen_number -> from(s in Student, where: s.pen_number == ^value)
      end

    query =
      if existing_student do
        from(s in query, where: s.id != ^existing_student.id)
      else
        query
      end

    # `Repo.exists?` (not `Repo.one`) - a `student_id` can legitimately match multiple rows
    # now that it is only unique within an auth group, which would crash `Repo.one`.
    Repo.exists?(query)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking student changes.

  ## Examples

      iex> change_student(student)
      %Ecto.Changeset{data: %Student{}}

  """
  def change_student(%Student{} = student, attrs \\ %{}) do
    Student.changeset(student, attrs)
  end

  alias Dbservice.Users.Teacher
  alias Dbservice.Users.Candidate

  @doc """
  Returns the list of teacher.

  ## Examples

      iex> list_teacher()
      [%Teacher{}, ...]

  """
  def list_teacher do
    Repo.all(Teacher)
  end

  @doc """
  Gets a single teacher.

  Raises `Ecto.NoResultsError` if the Teacher does not exist.

  ## Examples

      iex> get_teacher!(123)
      %Teacher{}

      iex> get_teacher!(456)
      ** (Ecto.NoResultsError)

  """
  def get_teacher!(id), do: Repo.get!(Teacher, id)

  @doc """
  Gets a Teacher by teacher ID.
  Returns nil when no teacher matches, or when the given teacher ID is
  nil/blank (teacher_id is optional, so code-less teachers exist and
  callers may pass through missing request/import values).
  ## Examples
      iex> get_teacher_by_teacher_id("AF123")
      %Teacher{}
      iex> get_teacher_by_teacher_id("no-such-code")
      nil
      iex> get_teacher_by_teacher_id(nil)
      nil
  """
  def get_teacher_by_teacher_id(teacher_id) when is_nil(teacher_id) or teacher_id == "",
    do: nil

  def get_teacher_by_teacher_id(teacher_id) do
    Repo.get_by(Teacher, teacher_id: teacher_id)
  end

  @doc """
  Creates a teacher.

  ## Examples

      iex> create_teacher(%{field: value})
      {:ok, %Teacher{}}

      iex> create_teacher(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_teacher(attrs \\ %{}) do
    %Teacher{}
    |> Teacher.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a teacher.

  ## Examples

      iex> update_teacher(teacher, %{field: new_value})
      {:ok, %Teacher{}}

      iex> update_teacher(teacher, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_teacher(%Teacher{} = teacher, attrs) do
    teacher
    |> Teacher.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a teacher.

  ## Examples

      iex> delete_teacher(teacher)
      {:ok, %Teacher{}}

      iex> delete_teacher(teacher)
      {:error, %Ecto.Changeset{}}

  """
  def delete_teacher(%Teacher{} = teacher) do
    Repo.delete(teacher)
  end

  @doc """
  Creates a user first and then the teacher.

  ## Examples

      iex> create_teacher_with_user(%{field: value})
      {:ok, %Teacher{}}

      iex> create_teacher_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_teacher_with_user(attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.create_user(attrs),
         {:ok, %Teacher{} = teacher} <-
           Users.create_teacher(Map.merge(stringify_keys(attrs), %{"user_id" => user.id})) do
      {:ok, teacher}
    end
  end

  @doc """
  Updates a user first and then the teacher.

  ## Examples

      iex> update_teacher_with_user(%{field: value})
      {:ok, %Teacher{}}

      iex> update_teacher_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_teacher_with_user(teacher, user, attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.update_user(user, attrs),
         {:ok, %Teacher{} = teacher} <-
           Users.update_teacher(
             teacher,
             Map.merge(stringify_keys(attrs), %{"user_id" => user.id})
           ) do
      {:ok, teacher}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking teacher changes.

  ## Examples

      iex> change_teacher(teacher)
      %Ecto.Changeset{data: %Teacher{}}

  """
  def change_teacher(%Teacher{} = teacher, attrs \\ %{}) do
    Teacher.changeset(teacher, attrs)
  end

  @doc """
  Returns the list of candidate.

  ## Examples

      iex> list_candidate()
      [%Candidate{}, ...]

  """
  def list_candidate do
    Repo.all(Candidate)
  end

  @doc """
  Gets a single candidate.

  Raises `Ecto.NoResultsError` if the Candidate does not exist.

  ## Examples

      iex> get_candidate!(123)
      %Candidate{}

      iex> get_candidate!(456)
      ** (Ecto.NoResultsError)

  """
  def get_candidate!(id), do: Repo.get!(Candidate, id)

  @doc """
  Gets a Candidate by candidate ID.
  Raises `Ecto.NoResultsError` if the Candidate does not exist.
  ## Examples
      iex> get_candidate_by_candidate_id(1234)
      %Candidate{}
      iex> get_candidate_by_candidate_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_candidate_by_candidate_id(candidate_id) do
    Repo.get_by(Candidate, candidate_id: candidate_id)
  end

  @doc """
  Creates a candidate.

  ## Examples

      iex> create_candidate(%{field: value})
      {:ok, %Candidate{}}

      iex> create_candidate(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_candidate(attrs \\ %{}) do
    %Candidate{}
    |> Candidate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a candidate.

  ## Examples

      iex> update_candidate(candidate, %{field: new_value})
      {:ok, %Candidate{}}

      iex> update_candidate(candidate, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_candidate(%Candidate{} = candidate, attrs) do
    candidate
    |> Candidate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a candidate.

  ## Examples

      iex> delete_candidate(candidate)
      {:ok, %Candidate{}}

      iex> delete_candidate(candidate)
      {:error, %Ecto.Changeset{}}

  """
  def delete_candidate(%Candidate{} = candidate) do
    Repo.delete(candidate)
  end

  @doc """
  Creates a user first and then the candidate.

  ## Examples

      iex> create_candidate_with_user(%{field: value})
      {:ok, %Candidate{}}

      iex> create_candidate_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_candidate_with_user(attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.create_user(attrs),
         {:ok, %Candidate{} = candidate} <-
           Users.create_candidate(Map.merge(attrs, %{"user_id" => user.id})) do
      {:ok, candidate}
    end
  end

  @doc """
  Updates a user first and then the candidate.

  ## Examples

      iex> update_candidate_with_user(%{field: value})
      {:ok, %Candidate{}}

      iex> update_candidate_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_candidate_with_user(candidate, user, attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.update_user(user, attrs),
         {:ok, %Candidate{} = candidate} <-
           Users.update_candidate(candidate, Map.merge(attrs, %{"user_id" => user.id})) do
      {:ok, candidate}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking candidate changes.

  ## Examples

      iex> change_candidate(candidate)
      %Ecto.Changeset{data: %Candidate{}}

  """
  def change_candidate(%Candidate{} = candidate, attrs \\ %{}) do
    Candidate.changeset(candidate, attrs)
  end

  @doc """
  Gets students based on the given parameters.
  Returns an empty list if no students are found.

  ## Examples

      iex> StudentContext.get_students_by_params(%{grade_id: 1, category: "category"})
      [%Student{}, ...]
  """
  def get_students_by_params(params) when is_map(params) do
    Student
    |> where(^Util.build_conditions(params))
    |> Repo.all()
  end

  @doc """
  Gets a user based on the given parameters.
  Returns an empty list if no user is found.
  """
  def get_user_by_params(params) when is_map(params) do
    User
    |> where(^Util.build_conditions(params))
    |> Repo.all()
  end

  @doc """
  Gets a list of students along with their associated users based on the given parameters.
  Returns an empty list if no matching students or users are found.
  """
  def get_students_with_users(grade_id, category, date_of_birth, gender, first_name) do
    from(s in Student,
      join: u in User,
      on: u.id == s.user_id,
      where:
        s.grade_id == ^grade_id and
          s.category == ^category and
          u.date_of_birth == ^date_of_birth and
          u.gender == ^gender and
          u.first_name == ^first_name,
      select: {s, u}
    )
    |> Repo.all()
  end

  defp stringify_keys(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  @doc """
  Gets a student by id and group.
  """
  def get_student_by_id_and_group(id, group) do
    case group do
      "EnableStudents" ->
        Repo.one(from s in Student, where: s.apaar_id == ^id or s.student_id == ^id)

      _ ->
        Repo.one(from s in Student, where: s.student_id == ^id)
    end
  end

  @doc """
  Enriches student params by converting grade number to grade_id if present.

  This is used when creating students via API or import to allow callers to
  specify grade as a number rather than looking up the grade_id.

  ## Examples

      iex> enrich_student_params(%{"grade" => 10, "first_name" => "John"})
      %{"grade" => 10, "grade_id" => 123, "first_name" => "John"}

      iex> enrich_student_params(%{"first_name" => "John"})
      %{"first_name" => "John"}
  """
  def enrich_student_params(params) do
    case Map.get(params, "grade") do
      nil ->
        params

      grade ->
        case Dbservice.Grades.get_grade_by_number(grade) do
          %Dbservice.Grades.Grade{} = grade_record ->
            Map.put(params, "grade_id", grade_record.id)

          _ ->
            params
        end
    end
  end
end
