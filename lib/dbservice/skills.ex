defmodule Dbservice.Skills do
  @moduledoc """
  The Exams context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Skills.Skill

  @doc """
  Returns the list of Skills.
  ## Examples
      iex> list_skill()
      [%Skill{}, ...]
  """
  def list_skill do
    Repo.all(Skill)
  end

  @doc """
  Gets a single skill.
  Raises `Ecto.NoResultsError` if the skill does not exist.
  ## Examples
      iex> get_skill!(123)
      %Skill{}
      iex> get_skill!(456)
      ** (Ecto.NoResultsError)
  """
  def get_skill!(id) do
    Repo.get!(Skill, id)
  end

  @doc """
  Gets a Skill by name.
  Raises `Ecto.NoResultsError` if the Skill does not exist.
  ## Examples
      iex> get_skill_by_name(JEE)
      %Skill{}
      iex> get_skill_by_name(123)
      ** (Ecto.NoResultsError)
  """
  def get_skill_by_name(name) do
    Repo.get_by(Skill, name: name)
  end

  @doc """
  Creates a Skill.
  ## Examples
      iex> create_skill(%{field: value})
      {:ok, %Skill{}}
      iex> create_skill(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_skill(attrs \\ %{}) do
    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Skill.
  ## Examples
      iex> update_skill(skill, %{field: new_value})
      {:ok, %Skill{}}
      iex> update_skill(skill, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_skill(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Skill.
  ## Examples
      iex> delete_skill(skill)
      {:ok, %Skill{}}
      iex> delete_skill(skill)
      {:error, %Ecto.Changeset{}}
  """
  def delete_skill(%Skill{} = skill) do
    Repo.delete(skill)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking Skill changes.
  ## Examples
      iex> change_skill(skill)
      %Ecto.Changeset{data: %Skill{}}
  """
  def change_skill(%Skill{} = skill, attrs \\ %{}) do
    Skill.changeset(skill, attrs)
  end
end
