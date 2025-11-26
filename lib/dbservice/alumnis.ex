defmodule Dbservice.Alumnis do
  @moduledoc """
  The Alumnis context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Alumnis.Alumni

  @doc """
  Returns the list of alumni.

  ## Examples

      iex> list_alumni()
      [%Alumni{}, ...]

  """
  def list_alumni do
    Repo.all(Alumni)
  end

  @doc """
  Gets a single alumni.

  Returns `nil` if the Alumni does not exist.

  ## Examples

      iex> get_alumni(123)
      %Alumni{}

      iex> get_alumni(456)
      nil

  """
  def get_alumni(id), do: Repo.get(Alumni, id)

  @doc """
  Gets an alumni by student_id.

  Returns `nil` if the Alumni does not exist.

  ## Examples

      iex> get_alumni_by_student_id(123)
      %Alumni{}

      iex> get_alumni_by_student_id(456)
      nil

  """
  def get_alumni_by_student_id(student_id) do
    Repo.get_by(Alumni, student_id: student_id)
  end

  @doc """
  Creates an alumni.

  ## Examples

      iex> create_alumni(%{field: value})
      {:ok, %Alumni{}}

      iex> create_alumni(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_alumni(attrs \\ %{}) do
    %Alumni{}
    |> Alumni.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an alumni.

  ## Examples

      iex> update_alumni(alumni, %{field: new_value})
      {:ok, %Alumni{}}

      iex> update_alumni(alumni, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_alumni(%Alumni{} = alumni, attrs) do
    alumni
    |> Alumni.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an alumni.

  ## Examples

      iex> delete_alumni(alumni)
      {:ok, %Alumni{}}

      iex> delete_alumni(alumni)
      {:error, %Ecto.Changeset{}}

  """
  def delete_alumni(%Alumni{} = alumni) do
    Repo.delete(alumni)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking alumni changes.

  ## Examples

      iex> change_alumni(alumni)
      %Ecto.Changeset{data: %Alumni{}}

  """
  def change_alumni(%Alumni{} = alumni, attrs \\ %{}) do
    Alumni.changeset(alumni, attrs)
  end
end
