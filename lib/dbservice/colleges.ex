defmodule Dbservice.Colleges do
  @moduledoc """
  The Colleges context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.Colleges.College

  @doc """
  Returns the list of colleges.

  ## Examples

      iex> list_colleges()
      [%College{}, ...]

  """
  def list_colleges do
    Repo.all(College)
  end

  @doc """
  Gets a single college.

  Raises `Ecto.NoResultsError` if the College does not exist.

  ## Examples

      iex> get_college!(123)
      %College{}

      iex> get_college!(456)
      ** (Ecto.NoResultsError)

  """
  def get_college!(id), do: Repo.get!(College, id)

  @doc """
  Gets a college by college_id.

  Returns `nil` if the College does not exist.

  ## Examples

      iex> get_college_by_college_id("COLL123")
      %College{}

      iex> get_college_by_college_id("NONEXISTENT")
      nil

  """
  def get_college_by_college_id(college_id) do
    Repo.get_by(College, college_id: college_id)
  end

  @doc """
  Returns college names only — one `%{college_id, name}` map per college,
  selecting just those two columns. Built for name dropdowns/autocomplete
  where the full college payload (20+ fields) is too heavy.

  Options in `params` (all optional):
    * `"name"` — case-insensitive substring match on the college name
    * `"limit"` / `"offset"` — pagination

  ## Examples

      iex> list_college_names(%{"name" => "iit", "limit" => "20"})
      [%{college_id: "C123", name: "IIT Madras"}, ...]

  """
  def list_college_names(params \\ %{}) do
    from(c in College,
      order_by: [asc: c.name],
      select: %{college_id: c.college_id, name: c.name}
    )
    |> filter_by_name_ilike(params)
    |> paginate(params)
    |> Repo.all()
  end

  defp filter_by_name_ilike(query, %{"name" => name}) when is_binary(name) and name != "" do
    from(q in query, where: ilike(q.name, ^"%#{name}%"))
  end

  defp filter_by_name_ilike(query, _), do: query

  defp paginate(query, params) do
    query
    |> maybe_limit(params["limit"])
    |> maybe_offset(params["offset"])
  end

  defp maybe_limit(query, limit) do
    case to_pagination_integer(limit) do
      nil -> query
      value -> from(q in query, limit: ^value)
    end
  end

  defp maybe_offset(query, offset) do
    case to_pagination_integer(offset) do
      nil -> query
      value -> from(q in query, offset: ^value)
    end
  end

  defp to_pagination_integer(value) when is_integer(value) and value >= 0, do: value

  defp to_pagination_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> int
      _ -> nil
    end
  end

  defp to_pagination_integer(_), do: nil

  @doc """
  Creates a college.

  ## Examples

      iex> create_college(%{field: value})
      {:ok, %College{}}

      iex> create_college(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_college(attrs \\ %{}) do
    %College{}
    |> College.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a college.

  ## Examples

      iex> update_college(college, %{field: new_value})
      {:ok, %College{}}

      iex> update_college(college, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_college(%College{} = college, attrs) do
    college
    |> College.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a college.

  ## Examples

      iex> delete_college(college)
      {:ok, %College{}}

      iex> delete_college(college)
      {:error, %Ecto.Changeset{}}

  """
  def delete_college(%College{} = college) do
    Repo.delete(college)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking college changes.

  ## Examples

      iex> change_college(college)
      %Ecto.Changeset{data: %College{}}

  """
  def change_college(%College{} = college, attrs \\ %{}) do
    College.changeset(college, attrs)
  end
end
