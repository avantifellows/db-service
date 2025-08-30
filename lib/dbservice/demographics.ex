defmodule Dbservice.Demographics do
  @moduledoc """
  The Demographics context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Demographics.DemographicProfile

  @doc """
  Returns the list of demographic_profiles.
  ## Examples
      iex> list_demographic_profile()
      [%DemographicProfile{}, ...]
  """
  def list_demographic_profile do
    Repo.all(DemographicProfile)
  end

  @doc """
  Gets a single demographic_profile.
  Raises `Ecto.NoResultsError` if the DemographicProfile does not exist.
  ## Examples
      iex> get_demographic_profile!(123)
      %DemographicProfile{}
      iex> get_demographic_profile!(456)
      ** (Ecto.NoResultsError)
  """
  def get_demographic_profile!(id) do
    Repo.get!(DemographicProfile, id)
  end

  @doc """
  Gets demographic profiles by category_id.
  ## Examples
      iex> get_demographic_profiles_by_category_id(1)
      [%DemographicProfile{}, ...]
  """
  def get_demographic_profiles_by_category_id(category_id) do
    DemographicProfile
    |> where([dp], dp.category_id == ^category_id)
    |> Repo.all()
  end

  @doc """
  Creates a demographic_profile.
  ## Examples
      iex> create_demographic_profile(%{field: value})
      {:ok, %DemographicProfile{}}
      iex> create_demographic_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_demographic_profile(attrs \\ %{}) do
    %DemographicProfile{}
    |> DemographicProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a demographic_profile.
  ## Examples
      iex> update_demographic_profile(demographic_profile, %{field: new_value})
      {:ok, %DemographicProfile{}}
      iex> update_demographic_profile(demographic_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_demographic_profile(%DemographicProfile{} = demographic_profile, attrs) do
    demographic_profile
    |> DemographicProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a demographic_profile.
  ## Examples
      iex> delete_demographic_profile(demographic_profile)
      {:ok, %DemographicProfile{}}
      iex> delete_demographic_profile(demographic_profile)
      {:error, %Ecto.Changeset{}}
  """
  def delete_demographic_profile(%DemographicProfile{} = demographic_profile) do
    Repo.delete(demographic_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking demographic_profile changes.
  ## Examples
      iex> change_demographic_profile(demographic_profile)
      %Ecto.Changeset{data: %DemographicProfile{}}
  """
  def change_demographic_profile(%DemographicProfile{} = demographic_profile, attrs \\ %{}) do
    DemographicProfile.changeset(demographic_profile, attrs)
  end
end
