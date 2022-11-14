defmodule Dbservice.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
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
  Updates the groups mapped to a user.
  """
  def update_groups(user_id, group_ids) when is_list(group_ids) do
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
  Returns an `%Ecto.Changeset{}` for tracking student changes.

  ## Examples

      iex> change_student(student)
      %Ecto.Changeset{data: %Student{}}

  """
  def change_student(%Student{} = student, attrs \\ %{}) do
    Student.changeset(student, attrs)
  end

  alias Dbservice.Users.Teacher

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
  Returns an `%Ecto.Changeset{}` for tracking teacher changes.

  ## Examples

      iex> change_teacher(teacher)
      %Ecto.Changeset{data: %Teacher{}}

  """
  def change_teacher(%Teacher{} = teacher, attrs \\ %{}) do
    Teacher.changeset(teacher, attrs)
  end
end
