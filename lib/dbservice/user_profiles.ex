defmodule Dbservice.Profiles do
  @moduledoc """
  The User Profiles context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Profiles.UserProfile

  @doc """
  Returns the list of user profiles.

  ## Examples

      iex> list_user_profiles()
      [%UserProfile{}, ...]

  """
  def list_all_user_profiles do
    Repo.all(UserProfile)
  end

  @doc """
  Gets a single user profile.

  Raises `Ecto.NoResultsError` if the User Profile does not exist.

  ## Examples

      iex> get_user_profile!(123)
      %UserProfile{}

      iex> get_user_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_profile!(id), do: Repo.get!(UserProfile, id)

  @doc """
  Gets a user profile by user ID.
  Raises `Ecto.NoResultsError` if the UserProfile does not exist.
  ## Examples
      iex> get_user_profile_by_user_id(1234)
      %UserProfile{}
      iex> get_user_profile_by_user_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_user_profile_by_user_id(user_id) do
    Repo.get_by(UserProfile, user_id: user_id)
  end

  @doc """
  Creates a user profile.

  ## Examples

      iex> create_user_profile(%{field: value})
      {:ok, %UserProfile{}}

      iex> create_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_profile(attrs \\ %{}) do
    %UserProfile{}
    |> UserProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user profile.

  ## Examples

      iex> update_user_profile(user_profile, %{field: new_value})
      {:ok, %UserProfile{}}

      iex> update_user_profile(user_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_profile(%UserProfile{} = user_profile, attrs) do
    user_profile
    |> UserProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user profile.

  ## Examples

      iex> delete_user_profile(user_profile)
      {:ok, %User{}}

      iex> delete_user_profile(user_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_profile(%UserProfile{} = user_profile) do
    Repo.delete(user_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_profile(user_profile)
      %Ecto.Changeset{data: %UserProfile{}}

  """
  def change_user_profile(%UserProfile{} = user_profile, attrs \\ %{}) do
    UserProfile.changeset(user_profile, attrs)
  end

  alias Dbservice.Profiles.StudentProfile

  @doc """
  Returns the list of student profiles.

  ## Examples

      iex> list_student_profiles()
      [%StudentProfile{}, ...]

  """
  def list_student_profiles do
    Repo.all(StudentProfile)
  end

  @doc """
  Gets a single student profile.

  Raises `Ecto.NoResultsError` if the StudentProfile does not exist.

  ## Examples

      iex> get_student_profile!(123)
      %StudentProfile{}

      iex> get_student_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_student_profile!(id), do: Repo.get!(StudentProfile, id)

  @doc """
  Gets a student profile by student ID.
  Raises `Ecto.NoResultsError` if the StudentProfile does not exist.
  ## Examples
      iex> get_student_profile_by_student_id(1234)
      %StudentProfile{}
      iex> get_student_profile_by_student_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_student_profile_by_student_id(student_id) do
    Repo.get_by(StudentProfile, student_id: student_id)
  end

  @doc """
  Creates a student profile.

  ## Examples

      iex> create_student_profile(%{field: value})
      {:ok, %StudentProfile{}}

      iex> create_student_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_student_profile(attrs \\ %{}) do
    %StudentProfile{}
    |> StudentProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a student profile.

  ## Examples

      iex> update_student_profile(student_profile, %{field: new_value})
      {:ok, %StudentProfile{}}

      iex> update_student_profile(student_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_student_profile(%StudentProfile{} = student_profile, attrs) do
    student_profile
    |> StudentProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a student profile.

  ## Examples

      iex> delete_student_profile(student_profile)
      {:ok, %StudentProfile{}}

      iex> delete_student_profile(student_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_student_profile(%StudentProfile{} = student_profile) do
    Repo.delete(student_profile)
  end

  @doc """
  Creates a user profile first and then the student profile.

  ## Examples

      iex> create_student_profile_with_user_profile(%{field: value})
      {:ok, %StudentProfile{}}

      iex> create_student_profile_with_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_student_profile_with_user_profile(attrs \\ %{}) do
    alias Dbservice.Profiles

    with {:ok, %UserProfile{} = user_profile} <- Profiles.create_user_profile(attrs),
         {:ok, %StudentProfile{} = student_profile} <-
           Profiles.create_student_profile(
             Map.merge(attrs, %{"user_profile_id" => user_profile.id})
           ) do
      {:ok, student_profile}
    end
  end

  @doc """
  Updates a user profile first and then the student profile.

  ## Examples

      iex> update_student_profile_with_user_profile(%{field: value})
      {:ok, %StudentProfile{}}

      iex> update_student_profile_with_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_student_profile_with_user_profile(student_profile, user_profile, attrs \\ %{}) do
    alias Dbservice.Profiles

    with {:ok, %UserProfile{} = user_profile} <-
           Profiles.update_user_profile(user_profile, attrs),
         {:ok, %StudentProfile{} = student_profile} <-
           Profiles.update_student_profile(
             student_profile,
             Map.merge(attrs, %{"user_profile_id" => user_profile.id})
           ) do
      {:ok, student_profile}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking student profile changes.

  ## Examples

      iex> change_student_profile(student_profile)
      %Ecto.Changeset{data: %StudentProfile{}}

  """
  def change_student_profile(%StudentProfile{} = student_profile, attrs \\ %{}) do
    StudentProfile.changeset(student_profile, attrs)
  end

  alias Dbservice.Profiles.TeacherProfile

  @doc """
  Returns the list of teacher profiles.

  ## Examples

      iex> list_teacher_profiles()
      [%TeacherProfile{}, ...]

  """
  def list_teacher_profiles do
    Repo.all(TeacherProfile)
  end

  @doc """
  Gets a single teacher_profile.

  Raises `Ecto.NoResultsError` if the TeacherProfile does not exist.

  ## Examples

      iex> get_teacher_profile!(123)
      %TeacherProfile{}

      iex> get_teacher_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_teacher_profile!(id), do: Repo.get!(TeacherProfile, id)

  @doc """
  Gets a teacher profile by teacher ID.
  Raises `Ecto.NoResultsError` if the TeacherProfile does not exist.
  ## Examples
      iex> get_teacher_profile_by_teacher_id(1234)
      %TeacherProfile{}
      iex> get_teacher_profile_by_teacher_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_teacher_profile_by_teacher_id(teacher_id) do
    Repo.get_by(TeacherProfile, teacher_id: teacher_id)
  end

  @doc """
  Creates a teacher profile.

  ## Examples

      iex> create_teacher_profile(%{field: value})
      {:ok, %TeacherProfile{}}

      iex> create_teacher_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_teacher_profile(attrs \\ %{}) do
    %TeacherProfile{}
    |> TeacherProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a teacher profile.

  ## Examples

      iex> update_teacher_profile(teacher_profile, %{field: new_value})
      {:ok, %TeacherProfile{}}

      iex> update_teacher_profile(teacher_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_teacher_profile(%TeacherProfile{} = teacher_profile, attrs) do
    teacher_profile
    |> TeacherProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a teacher profile.

  ## Examples

      iex> delete_teacher_profile(teacher_profile)
      {:ok, %TeacherProfile{}}

      iex> delete_teacher_profile(teacher_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_teacher_profile(%TeacherProfile{} = teacher_profile) do
    Repo.delete(teacher_profile)
  end

  @doc """
  Creates a user profile first and then the teacher_profile.

  ## Examples

      iex> create_teacher_profile_with_user_profile(%{field: value})
      {:ok, %TeacherProfile{}}

      iex> create_teacher_profile_with_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_teacher_profile_with_user_profile(attrs \\ %{}) do
    alias Dbservice.Profiles

    with {:ok, %UserProfile{} = user_profile} <- Profiles.create_user_profile(attrs),
         {:ok, %TeacherProfile{} = teacher_profile} <-
           Profiles.create_teacher_profile(
             Map.merge(attrs, %{"user_profile_id" => user_profile.id})
           ) do
      {:ok, teacher_profile}
    end
  end

  @doc """
  Updates a user profile first and then the teacher profile.

  ## Examples

      iex> update_teacher_profile_with_user_profile(%{field: value})
      {:ok, %TeacherProfile{}}

      iex> update_teacher_profile_with_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_teacher_profile_with_user_profile(teacher_profile, user_profile, attrs \\ %{}) do
    alias Dbservice.Profiles

    with {:ok, %UserProfile{} = user_profile} <-
           Profiles.update_user_profile(user_profile, attrs),
         {:ok, %TeacherProfile{} = teacher_profile} <-
           Profiles.update_teacher_profile(
             teacher_profile,
             Map.merge(attrs, %{"user_profile_id" => user_profile.id})
           ) do
      {:ok, teacher_profile}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking teacher profile changes.

  ## Examples

      iex> change_teacher_profile(teacher_profile)
      %Ecto.Changeset{data: %TeacherProfile{}}

  """
  def change_teacher_profile(%TeacherProfile{} = teacher_profile, attrs \\ %{}) do
    TeacherProfile.changeset(teacher_profile, attrs)
  end
end
