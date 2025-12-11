defmodule Dbservice.CmsStatuses do
  @moduledoc """
  The CmsStatuses context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.CmsStatuses.CmsStatus

  @doc """
  Returns the list of cms_status.
  ## Examples
      iex> list_cms_status()
      [%CmsStatus{}, ...]
  """
  def list_cms_status do
    Repo.all(CmsStatus)
  end

  @doc """
  Gets a single cms_status.
  Raises `Ecto.NoResultsError` if the cms_status does not exist.
  ## Examples
      iex> get_cms_status!(123)
      %CmsStatus{}
      iex> get_cms_status!(456)
      ** (Ecto.NoResultsError)
  """
  def get_cms_status!(id), do: Repo.get!(CmsStatus, id)

  @doc """
  Creates a cms_status.
  ## Examples
      iex> create_cms_status(%{field: value})
      {:ok, %CmsStatus{}}
      iex> create_cms_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_cms_status(attrs \\ %{}) do
    %CmsStatus{}
    |> CmsStatus.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cms_status.
  ## Examples
      iex> update_cms_status(cms_status, %{field: new_value})
      {:ok, %CmsStatus{}}
      iex> update_cms_status(cms_status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_cms_status(%CmsStatus{} = cms_status, attrs) do
    cms_status
    |> CmsStatus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cms_status.
  ## Examples
      iex> delete_cms_status(cms_status)
      {:ok, %CmsStatus{}}
      iex> delete_cms_status(cms_status)
      {:error, %Ecto.Changeset{}}
  """
  def delete_cms_status(%CmsStatus{} = cms_status) do
    Repo.delete(cms_status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cms_status changes.
  ## Examples
      iex> change_cms_status(cms_status)
      %Ecto.Changeset{data: %CmsStatus{}}
  """
  def change_cms_status(%CmsStatus{} = cms_status, attrs \\ %{}) do
    CmsStatus.changeset(cms_status, attrs)
  end
end
