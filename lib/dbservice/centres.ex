defmodule Dbservice.Centres do
  @moduledoc """
  The Centres context.

  Centres are currently written by AF LMS straight into Postgres, so this
  context is read-mostly from db-service's point of view. Its main job is to
  resolve a centre to the `group` row that carries its membership, the same way
  batches and schools are resolved (`group.type == "centre"`, `child_id ==
  centres.id`).

  Every centre is guaranteed a group row by the DB trigger installed in
  `20260918120000_create_centre_groups` — backfilled for existing rows and
  created automatically for new ones, whoever inserts them.
  """

  import Ecto.Query, warn: false

  alias Dbservice.Repo
  alias Dbservice.Centres.Centre
  alias Dbservice.Groups.Group

  @group_type "centre"

  @doc """
  Returns the list of centres.
  ## Examples
      iex> list_centres()
      [%Centre{}, ...]
  """
  def list_centres do
    Repo.all(Centre)
  end

  @doc """
  Gets a single centre.
  Raises `Ecto.NoResultsError` if the centre does not exist.
  ## Examples
      iex> get_centre!(123)
      %Centre{}
      iex> get_centre!(456)
      ** (Ecto.NoResultsError)
  """
  def get_centre!(id), do: Repo.get!(Centre, id)

  @doc """
  Gets a single centre. Returns nil if it does not exist.
  ## Examples
      iex> get_centre(123)
      %Centre{}
      iex> get_centre(456)
      nil
  """
  def get_centre(id), do: Repo.get(Centre, id)

  @doc """
  Gets the single ACTIVE centre for a school and program.

  `centres_active_school_program_unique` guarantees at most one, so this is a
  safe way to name a centre without a business code (centres have none).
  """
  def get_active_centre_by_school_and_program(school_id, program_id)
      when not is_nil(school_id) and not is_nil(program_id) do
    Repo.one(
      from c in Centre,
        where: c.school_id == ^school_id and c.program_id == ^program_id and c.is_active == true
    )
  end

  def get_active_centre_by_school_and_program(_school_id, _program_id), do: nil

  @doc """
  Gets the `group` row that carries a centre's membership.
  Returns nil when the centre has no group row.
  """
  def get_centre_group(centre_id) do
    Repo.get_by(Group, child_id: centre_id, type: @group_type)
  end

  @doc """
  Creates a centre.

  The `centres_ensure_group_trigger` installed in 20260918120000 creates the
  matching `group` row as part of the same insert, so the returned centre is
  immediately addressable for enrollment.

  ## Examples
      iex> create_centre(%{name: "Bathinda CoE"})
      {:ok, %Centre{}}
      iex> create_centre(%{})
      {:error, %Ecto.Changeset{}}
  """
  def create_centre(attrs \\ %{}) do
    %Centre{}
    |> Centre.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a centre.
  ## Examples
      iex> update_centre(centre, %{field: new_value})
      {:ok, %Centre{}}
      iex> update_centre(centre, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_centre(%Centre{} = centre, attrs) do
    centre
    |> Centre.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a centre.
  ## Examples
      iex> delete_centre(centre)
      {:ok, %Centre{}}
  """
  def delete_centre(%Centre{} = centre) do
    Repo.delete(centre)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking centre changes.
  ## Examples
      iex> change_centre(centre)
      %Ecto.Changeset{data: %Centre{}}
  """
  def change_centre(%Centre{} = centre, attrs \\ %{}) do
    Centre.changeset(centre, attrs)
  end
end
