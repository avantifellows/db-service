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

  def get_cms_status_by_name(name) when is_binary(name) do
    Repo.get_by(CmsStatus, name: String.downcase(name))
  end

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

  def ensure_cms_status_id(attrs) when is_map(attrs) do
    attrs = normalize_keys(attrs)

    cond do
      Map.has_key?(attrs, "cms_status_id") ->
        {:ok, Map.delete(attrs, "cms_status")}

      status_name = attrs["cms_status"] ->
        case get_cms_status_by_name(status_name) do
          nil ->
            {:error, "cms_status '#{status_name}' not found"}

          %CmsStatus{id: id} ->
            {:ok, attrs |> Map.put("cms_status_id", id) |> Map.delete("cms_status")}
        end

      true ->
        {:ok, attrs}
    end
  end

  defp normalize_keys(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      normalized_key = if is_atom(key), do: Atom.to_string(key), else: key
      Map.put(acc, normalized_key, value)
    end)
  end
end
