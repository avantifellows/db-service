defmodule Dbservice.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ProblemLanguage

  @doc """
  Returns the list of resource.
  ## Examples
      iex> list_resource()
      [%Resource{}, ...]
  """
  def list_resource do
    Repo.all(Resource)
  end

  @doc """
  Gets a single resource.
  Raises `Ecto.NoResultsError` if the resource does not exist.
  ## Examples
      iex> get_resource!(123)
      %Resource{}
      iex> get_resource!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource!(id), do: Repo.get!(Resource, id)

  @doc """
  Gets all problems for a specific test in a specific language.

  ## Parameters
    - test_id: ID of the test resource
    - lang_id: ID of the language to fetch problems in

  ## Returns
    - List of problem resources with their metadata from problem_lang table
  """
  def get_problems_by_test_and_language(test_id, lang_id) do
    # First, get the test resource to extract problem IDs
    with %Resource{} = test_resource <- Repo.get(Resource, test_id),
         true <- test_resource.type == "test" do
      # Extract all problem IDs from the test resource's type_params
      problem_ids = extract_problem_ids_from_test(test_resource.type_params)

      # Query for all problems with those IDs
      problems =
        from(r in Resource,
          where: r.id in ^problem_ids and r.type == "problem"
        )
        |> Repo.all()

      # For each problem, fetch and merge the language metadata
      Enum.map(problems, fn problem ->
        meta_data =
          from(pl in ProblemLanguage,
            where: pl.res_id == ^problem.id and pl.lang_id == ^lang_id,
            select: pl.meta_data
          )
          |> Repo.one()

        # Add the meta_data field to the problem
        Map.put(problem, :meta_data, meta_data)
      end)
    else
      nil -> {:error, :test_not_found}
      false -> {:error, :resource_not_test_type}
      error -> error
    end
  end

  @doc """
  Recursively extracts all problem IDs from a test's type_params structure.

  This handles the nested structure with subjects, sections, and both
  compulsory and optional problem lists.
  """
  def extract_problem_ids_from_test(type_params) do
    subjects = Map.get(type_params, "subjects", [])
    extract_problems_from_subjects(subjects)
  end

  defp extract_problems_from_subjects(subjects) do
    Enum.flat_map(subjects, fn subject ->
      sections = Map.get(subject, "sections", [])
      extract_problems_from_sections(sections)
    end)
  end

  defp extract_problems_from_sections(sections) do
    Enum.flat_map(sections, fn section ->
      extract_problems_from_section(section)
    end)
  end

  defp extract_problems_from_section(section) do
    compulsory_problems = get_in(section, ["compulsory", "problems"]) || []
    optional_problems = get_in(section, ["optional", "problems"]) || []

    (compulsory_problems ++ optional_problems)
    |> Enum.map(fn problem -> Map.get(problem, "id") end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns a list of unique subtypes for a given type.

  ## Examples

      iex> list_subtypes_by_type("test")
      ["subtype1", "subtype2", "subtype3"]

      iex> list_subtypes_by_type("nonexistent")
      []
  """
  def list_subtypes_by_type(type) do
    query =
      from(r in Resource,
        where: r.type == ^type and not is_nil(r.subtype),
        select: r.subtype,
        distinct: true,
        order_by: r.subtype
      )

    Repo.all(query)
  end

  @doc """
  Gets a resource by name and sourceId.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_resource_by_type_and_type_params("abc",{"src_link": "youtube"})
      %Resource{}

      iex> get_resource_by_type_and_type_params("abc", {"src_link": "youtube"})
      ** (Ecto.NoResultsError)

  """
  def get_resource_by_type_and_type_params(type, type_params) do
    Repo.get_by(Resource, type: type, type_params: type_params)
  end

  @doc """
  Creates a resource.
  ## Examples
      iex> create_resource(%{field: value})
      {:ok, %Resource{}}
      iex> create_resource(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource(attrs \\ %{}) do
    %Resource{}
    |> Resource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource.
  ## Examples
      iex> update_resource(resource, %{field: new_value})
      {:ok, %Resource{}}
      iex> update_resource(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource.
  ## Examples
      iex> delete_resource(resource)
      {:ok, %Resource{}}
      iex> delete_resource(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource(%Resource{} = resource) do
    Repo.delete(resource)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.
  ## Examples
      iex> change_resource(resource)
      %Ecto.Changeset{data: %Resource{}}
  """
  def change_resource(%Resource{} = resource, attrs \\ %{}) do
    Resource.changeset(resource, attrs)
  end
end
