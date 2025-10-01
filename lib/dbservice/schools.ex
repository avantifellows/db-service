defmodule Dbservice.Schools do
  @moduledoc """
  The Schools context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Utils.Util
  alias Dbservice.Repo

  alias Dbservice.Groups.Group
  alias Dbservice.Schools.School
  alias Dbservice.Users.User
  alias Dbservice.Schools

  @doc """
  Returns the list of school.

  ## Examples

      iex> list_school()
      [%School{}, ...]

  """
  def list_school do
    Repo.all(School)
  end

  @doc """
  Gets a single school.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_school!(123)
      %School{}

      iex> get_school!(456)
      ** (Ecto.NoResultsError)

  """
  def get_school!(id), do: Repo.get!(School, id)

  @doc """
  Gets a school by code.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_school_by_code(872931)
      %School{}

      iex> get_school_by_code(872931)
      ** (Ecto.NoResultsError)

  """
  def get_school_by_code(code) do
    Repo.get_by(School, code: code)
  end

  @doc """
  Creates a school.

  ## Examples

      iex> create_school(%{field: value})
      {:ok, %School{}}

      iex> create_school(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_school(attrs \\ %{}) do
    %School{}
    |> School.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [
      %Group{type: "school", child_id: attrs["id"]}
    ])
    |> Repo.insert()
  end

  @doc """
  Updates a school.

  ## Examples

      iex> update_school(school, %{field: new_value})
      {:ok, %School{}}

      iex> update_school(school, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_school(%School{} = school, attrs) do
    school
    |> School.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a school.

  ## Examples

      iex> delete_school(school)
      {:ok, %School{}}

      iex> delete_school(school)
      {:error, %Ecto.Changeset{}}

  """
  def delete_school(%School{} = school) do
    Repo.delete(school)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking school changes.

  ## Examples

      iex> change_school(school)
      %Ecto.Changeset{data: %School{}}

  """
  def change_school(%School{} = school, attrs \\ %{}) do
    School.changeset(school, attrs)
  end

  @doc """
  Gets a list of schools based on the given parameters.
  Returns empty list - [] if no school with the given parameters is found.
  """
  def get_school_by_params(params) when is_map(params) do
    query = from s in School, where: ^Util.build_conditions(params), select: s

    Repo.all(query)
  end

  @doc """
  Creates a user first and then the school.

  ## Examples

      iex> create_school_with_user(%{field: value})
      {:ok, %School{}}

      iex> create_school_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_school_with_user(attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.create_user(attrs),
         {:ok, %School{} = school} <-
           Schools.create_school(Map.merge(stringify_keys(attrs), %{"user_id" => user.id})) do
      {:ok, school}
    end
  end

  defp stringify_keys(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  @doc """
  Updates a user first and then the school.

  ## Examples

      iex> update_school_with_user(%{field: value})
      {:ok, %School{}}

      iex> update_school_with_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_school_with_user(school, user, attrs \\ %{}) do
    alias Dbservice.Users

    with {:ok, %User{} = user} <- Users.update_user(user, attrs),
         {:ok, %School{} = school} <-
           Schools.update_school(
             school,
             Map.merge(stringify_keys(attrs), %{"user_id" => user.id})
           ) do
      {:ok, school}
    end
  end
end
