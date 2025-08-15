defmodule Dbservice.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
  alias Dbservice.Repo

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
    Repo.get_by(User, user_id: user_id)
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
  Gets a student by student ID.
  Raises `Ecto.NoResultsError` if the Student does not exist.
  ## Examples
      iex> get_student_by_student_id(1234)
      %Student{}
      iex> get_student_by_student_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_student_by_student_id(student_id) do
    Repo.get_by(Student, student_id: student_id)
  end

  @doc """
  Gets a student by either student_id or apaar_id.
  Returns the first student found with either identifier.

  ## Examples

      iex> get_student_by_id_or_apaar_id(%{"student_id" => "1234", "apaar_id" => nil})
      %Student{}
      iex> get_student_by_id_or_apaar_id(%{"student_id" => nil, "apaar_id" => "123456789101"})
      %Student{}
      iex> get_student_by_id_or_apaar_id(%{"student_id" => nil, "apaar_id" => nil})
      nil
  """
  def get_student_by_id_or_apaar_id(%{"student_id" => student_id, "apaar_id" => apaar_id}) do
    cond do
      student_id && student_id != "" ->
        get_student_by_student_id(student_id)

      apaar_id && apaar_id != "" ->
        Repo.get_by(Student, apaar_id: apaar_id)

      true ->
        nil
    end
  end

  def get_student_by_id_or_apaar_id(record) when is_map(record) do
    student_id = Map.get(record, "student_id")
    apaar_id = Map.get(record, "apaar_id")
    get_student_by_id_or_apaar_id(%{"student_id" => student_id, "apaar_id" => apaar_id})
  end

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

    with {:ok, %User{} = user} <- Users.create_user(attrs),
         {:ok, %Student{} = student} <-
           Users.create_student(Map.merge(attrs, %{"user_id" => user.id})) do
      {:ok, student}
    end
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
           Users.update_student(student, Map.merge(attrs, %{"user_id" => user.id})) do
      {:ok, student}
    end
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
  Raises `Ecto.NoResultsError` if the Batch does not exist.
  ## Examples
      iex> get_teacher_by_teacher_id(1234)
      %Teacher{}
      iex> get_teacher_by_teacher_id(abc)
      ** (Ecto.NoResultsError)
  """
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
           Users.create_teacher(Map.merge(attrs, %{"user_id" => user.id})) do
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
           Users.update_teacher(teacher, Map.merge(attrs, %{"user_id" => user.id})) do
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
end
